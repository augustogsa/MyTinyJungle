package api

import (
	"math"
	"net/http"
	"sort"
	"time"
)

// North-star metrics for the admin dashboard (GET /v1/admin/metrics):
//   survival   per user (jungle owner): of plants older than 30 days, the share not archived as "passed".
//              Plants given away or deleted leave the count.
//   adherence  per plant over the last 30 days: waterings logged ÷ waterings expected (30 / interval), capped
//              at 1, averaged per user, then across users. Only plants older than 14 days.
//   identify   correction rate from POST /v1/brain/identify/feedback (daily counts, no ids), last 30 days.
//   diagnosis  helpful share from diagnosis feedback (ai_library good/bad).

// POST /v1/brain/identify/feedback {suggested, chosen?}: the owner kept our top guess, picked another, or none.
func (s *Server) identifyFeedback(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Suggested string `json:"suggested"`
		Chosen    string `json:"chosen"`
	}
	if decode(r, &in) != nil || in.Suggested == "" || len(in.Suggested) > 120 || len(in.Chosen) > 120 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	outcome := "corrected"
	switch in.Chosen {
	case in.Suggested:
		outcome = "confirmed"
	case "":
		outcome = "rejected"
	}
	_, _ = s.db.Auth.Exec(r.Context(), `insert into identify_feedback (outcome, n) values ($1, 1)
		on conflict (day, outcome) do update set n = identify_feedback.n + 1`, outcome)
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "outcome": outcome})
}

type metricDist struct {
	Users  int     `json:"users"`
	Mean   float64 `json:"mean"`
	Median float64 `json:"median"`
	P25    float64 `json:"p25"`
	P75    float64 `json:"p75"`
}

func dist(v []float64) metricDist {
	if len(v) == 0 {
		return metricDist{}
	}
	sort.Float64s(v)
	sum := 0.0
	for _, x := range v {
		sum += x
	}
	q := func(p float64) float64 { return round3(v[int(math.Round(p*float64(len(v)-1)))]) }
	return metricDist{Users: len(v), Mean: round3(sum / float64(len(v))), Median: q(0.5), P25: q(0.25), P75: q(0.75)}
}

func round3(f float64) float64 { return math.Round(f*1000) / 1000 }

func (s *Server) adminMetrics(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	now := s.now().UTC()
	rows, err := s.db.Admin.Query(ctx, `select j.owner_id::text, r.jungle_id::text, r.entity, r.id::text, r.data
		from records r join jungles j on j.id = r.jungle_id
		where not r.deleted and r.entity in ('plant', 'care_event')
		and (r.entity <> 'care_event' or (r.data->>'kind' = 'water' and jsonb_typeof(r.data->'date') = 'number' and (r.data->>'date')::float8 > $1))`,
		float64(now.AddDate(0, 0, -30).Unix()))
	if err != nil {
		s.fail(w, r, err)
		return
	}
	byOwner := map[string][]rec{}
	for rows.Next() {
		var owner string
		var x rec
		if rows.Scan(&owner, &x.jungle, &x.entity, &x.id, &x.data) == nil {
			byOwner[owner] = append(byOwner[owner], x)
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		s.fail(w, r, err)
		return
	}
	care := s.speciesLookup()
	var survival, adherence []float64
	plantsTotal, passedTotal := 0, 0
	for _, recs := range byOwner {
		old, passed := 0, 0
		for _, x := range recs {
			if x.entity != "plant" {
				continue
			}
			f, ok := num(x.data, "createdAt")
			if !ok || epoch(f).After(now.AddDate(0, 0, -30)) {
				continue
			}
			switch {
			case boolean(x.data, "isArchived") && str(x.data, "archivedReason") == "passed":
				old++
				passed++
			case !boolean(x.data, "isArchived"):
				old++
			}
		}
		if old > 0 {
			survival = append(survival, 1-float64(passed)/float64(old))
			plantsTotal += old
			passedTotal += passed
		}
		waters := map[string]int{}
		for _, x := range recs {
			if x.entity == "care_event" {
				waters[str(x.data, "plantID")]++
			}
		}
		var per []float64
		for _, p := range schedules(recs, now, care) {
			if p.Created.After(now.AddDate(0, 0, -14)) {
				continue
			}
			span := math.Min(30, now.Sub(p.Created).Hours()/24)
			expected := span / p.Interval
			if expected < 1 {
				continue
			}
			per = append(per, math.Min(1, float64(waters[p.ID])/expected))
		}
		if len(per) > 0 {
			sum := 0.0
			for _, v := range per {
				sum += v
			}
			adherence = append(adherence, sum/float64(len(per)))
		}
	}
	id := map[string]int64{"confirmed": 0, "corrected": 0, "rejected": 0}
	if rows, err := s.db.Admin.Query(ctx, `select outcome, sum(n)::bigint from identify_feedback where day > current_date - 30 group by outcome`); err == nil {
		for rows.Next() {
			var o string
			var n int64
			if rows.Scan(&o, &n) == nil {
				id[o] = n
			}
		}
		rows.Close()
	}
	idTotal := id["confirmed"] + id["corrected"] + id["rejected"]
	var corr *float64
	if idTotal > 0 {
		v := round3(float64(id["corrected"]+id["rejected"]) / float64(idTotal))
		corr = &v
	}
	var good, badN int64
	_ = s.db.Admin.QueryRow(ctx, `select coalesce(sum(good), 0)::bigint, coalesce(sum(bad), 0)::bigint from ai_library`).Scan(&good, &badN)
	var helpful *float64
	if good+badN > 0 {
		v := round3(float64(good) / float64(good+badN))
		helpful = &v
	}
	overall := 0.0
	if plantsTotal > 0 {
		overall = round3(1 - float64(passedTotal)/float64(plantsTotal))
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"at":        now.Format(time.RFC3339),
		"survival":  map[string]any{"perUser": dist(survival), "plants": plantsTotal, "passed": passedTotal, "overall": overall},
		"adherence": map[string]any{"perUser": dist(adherence)},
		"identify":  map[string]any{"days": 30, "confirmed": id["confirmed"], "corrected": id["corrected"], "rejected": id["rejected"], "correctionRate": corr},
		"diagnosis": map[string]any{"helpful": good, "notHelpful": badN, "helpfulRate": helpful},
	})
}
