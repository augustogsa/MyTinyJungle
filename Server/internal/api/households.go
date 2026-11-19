package api

import (
	"context"
	"errors"
	"net/http"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Households: people caring for one jungle's plants together. Roles: owner (manages members, invites and
// assignments) and carer. Joining a household also joins its jungle, so the plants sync to every member.
// The rotation spreads upcoming waterings fairly: assigned plants go to their carer, the rest to whoever
// has the fewest waterings in the last 30 days plus already scheduled turns.

type householdMember struct {
	UserID      string    `json:"userId"`
	DisplayName *string   `json:"displayName"`
	Role        string    `json:"role"`
	JoinedAt    time.Time `json:"joinedAt"`
}

type householdOut struct {
	ID          string            `json:"id"`
	JungleID    string            `json:"jungleId"`
	Name        string            `json:"name"`
	Role        string            `json:"role"`
	Members     []householdMember `json:"members"`
	Assignments []assignment      `json:"assignments"`
}

type assignment struct {
	PlantID string `json:"plantId"`
	UserID  string `json:"userId"`
}

func asNotFound(err error) error {
	if isNoRows(err) {
		return apiError{http.StatusNotFound, "not_found"}
	}
	return err
}

// POST /v1/households {name, jungleId?}: with no jungleId a new shared jungle is made for it.
func (s *Server) createHousehold(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name     string  `json:"name"`
		JungleID *string `json:"jungleId"`
	}
	if decode(r, &in) != nil || len(in.Name) > 60 || (in.JungleID != nil && !isUUID(*in.JungleID)) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	var out householdOut
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		jid := ""
		if in.JungleID != nil {
			jid = *in.JungleID
			var owns bool
			if err := tx.QueryRow(ctx, `select mtj_owns_jungle($1)`, jid).Scan(&owns); err != nil {
				return err
			}
			if !owns {
				return apiError{http.StatusForbidden, "not_owner"}
			}
		} else {
			if err := tx.QueryRow(ctx, `insert into jungles (owner_id, name) values ($1,$2) returning id`, c.Sub, in.Name).Scan(&jid); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into jungle_members (jungle_id, user_id, role) values ($1,$2,'owner')`, jid, c.Sub); err != nil {
				return err
			}
		}
		err := tx.QueryRow(ctx, `insert into households (jungle_id, owner_id, name) values ($1,$2,$3) on conflict (jungle_id) do nothing returning id`, jid, c.Sub, in.Name).Scan(&out.ID)
		if isNoRows(err) {
			return apiError{http.StatusConflict, "household_exists"}
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into household_members (household_id, user_id, role) values ($1,$2,'owner')`, out.ID, c.Sub); err != nil {
			return err
		}
		out.JungleID, out.Name, out.Role = jid, in.Name, "owner"
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"id": out.ID, "jungleId": out.JungleID, "name": out.Name})
}

func loadHousehold(ctx context.Context, tx pgx.Tx, uid, hid string) (householdOut, error) {
	h := householdOut{ID: hid, Members: []householdMember{}, Assignments: []assignment{}}
	if err := tx.QueryRow(ctx, `select jungle_id, name from households where id = $1`, hid).Scan(&h.JungleID, &h.Name); err != nil {
		return h, asNotFound(err)
	}
	rows, _ := tx.Query(ctx, `select user_id, display_name, role, joined_at from mtj_household_members($1)`, hid)
	ms, err := pgx.CollectRows(rows, pgx.RowToStructByPos[householdMember])
	if err != nil {
		return h, err
	}
	for _, m := range ms {
		if m.UserID == uid {
			h.Role = m.Role
		}
	}
	if ms != nil {
		h.Members = ms
	}
	rows, _ = tx.Query(ctx, `select plant_id::text, user_id::text from household_assignments where household_id = $1 order by assigned_at`, hid)
	as, err := pgx.CollectRows(rows, pgx.RowToStructByPos[assignment])
	if err != nil {
		return h, err
	}
	if as != nil {
		h.Assignments = as
	}
	if h.Role == "" {
		return h, apiError{http.StatusNotFound, "not_found"}
	}
	return h, nil
}

// GET /v1/households
func (s *Server) households(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	out := []householdOut{}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		rows, _ := tx.Query(ctx, `select id::text from households where id in (select mtj_my_households()) order by created_at`)
		ids, err := pgx.CollectRows(rows, pgx.RowTo[string])
		if err != nil {
			return err
		}
		for _, id := range ids {
			h, err := loadHousehold(ctx, tx, c.Sub, id)
			if err != nil {
				return err
			}
			out = append(out, h)
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"households": out})
}

// DELETE /v1/households/{id}: the creator ends the household (the jungle and its plants stay).
func (s *Server) deleteHousehold(w http.ResponseWriter, r *http.Request) {
	ctx, c, hid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(hid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from households where id = $1 and owner_id = $2`, hid, c.Sub)
		if err == nil && tag.RowsAffected() == 0 {
			return apiError{http.StatusNotFound, "not_found"}
		}
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/households/{id}/invites {role?}: single-use code, 7 days. Redeemed at POST /v1/invites/{code}/redeem
// (the same join link as shared jungles) or POST /v1/household-invites/{code}/redeem.
func (s *Server) createHouseholdInvite(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role string `json:"role"`
	}
	if decode(r, &in) != nil {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if in.Role == "" {
		in.Role = "carer"
	}
	ctx, c, hid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(hid) || (in.Role != "carer" && in.Role != "owner") {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	code := inviteCode()
	expires := s.now().Add(7 * 24 * time.Hour)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `insert into household_invites (code, household_id, role, created_by, expires_at)
			select $1, $2, $3, $4, $5 where mtj_household_owner($2)`, code, hid, in.Role, c.Sub, expires)
		if err == nil && tag.RowsAffected() == 0 {
			return apiError{http.StatusForbidden, "not_owner"}
		}
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"code": code, "url": "https://mytinyjungle.com/join/" + code, "expiresAt": expires})
}

// redeemHouseholdCode joins by code; ok=false when the code is not a live household invite.
func (s *Server) redeemHouseholdCode(ctx context.Context, uid, code string) (hid, jid string, ok bool, err error) {
	err = s.db.AsUser(ctx, uid, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select mtj_redeem_household_invite($1)`, code).Scan(&hid); err != nil {
			return err
		}
		return tx.QueryRow(ctx, `select jungle_id from households where id = $1`, hid).Scan(&jid)
	})
	var pe *pgconn.PgError
	if errors.As(err, &pe) && pe.Message == "invite_invalid" {
		return "", "", false, nil
	}
	if err == nil {
		s.pusher.jungleChanged(jid, uid)
	}
	return hid, jid, err == nil, err
}

// POST /v1/household-invites/{code}/redeem
func (s *Server) redeemHouseholdInvite(w http.ResponseWriter, r *http.Request) {
	hid, jid, ok, err := s.redeemHouseholdCode(r.Context(), claimsOf(r).Sub, r.PathValue("code"))
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if !ok {
		writeErr(w, http.StatusNotFound, "invite_invalid")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"householdId": hid, "jungleId": jid})
}

// PATCH /v1/households/{id}/members/{uid} {role}
func (s *Server) updateHouseholdMember(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role string `json:"role"`
	}
	ctx, c, hid, uid := r.Context(), claimsOf(r), r.PathValue("id"), r.PathValue("uid")
	if decode(r, &in) != nil || !isUUID(hid) || !isUUID(uid) || (in.Role != "carer" && in.Role != "owner") {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update household_members set role = $3 where household_id = $1 and user_id = $2 and mtj_household_owner($1)
			and user_id <> (select owner_id from households where id = $1)`, hid, uid, in.Role)
		if err == nil && tag.RowsAffected() == 0 {
			return apiError{http.StatusNotFound, "not_found"}
		}
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// DELETE /v1/households/{id}/members/{uid}: an owner removes someone, or anyone leaves with their own id.
// They also leave the household's jungle (unless they own it) and lose their assignments.
func (s *Server) removeHouseholdMember(w http.ResponseWriter, r *http.Request) {
	ctx, c, hid, uid := r.Context(), claimsOf(r), r.PathValue("id"), r.PathValue("uid")
	if !isUUID(hid) || !isUUID(uid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var jid string
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var creator string
		if err := tx.QueryRow(ctx, `select jungle_id, owner_id from households where id = $1`, hid).Scan(&jid, &creator); err != nil {
			return asNotFound(err)
		}
		if uid == creator {
			return apiError{http.StatusConflict, "creator_cannot_leave"}
		}
		var gone bool
		if err := tx.QueryRow(ctx, `select mtj_household_drop($1, $2)`, hid, uid).Scan(&gone); err != nil {
			return err
		}
		if !gone {
			return apiError{http.StatusNotFound, "not_found"}
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	s.pusher.jungleChanged(jid, c.Sub)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// PUT /v1/households/{id}/assignments {plantId, userId|null}: owners pin a plant to a member (null clears).
func (s *Server) putAssignment(w http.ResponseWriter, r *http.Request) {
	var in struct {
		PlantID string  `json:"plantId"`
		UserID  *string `json:"userId"`
	}
	ctx, c, hid := r.Context(), claimsOf(r), r.PathValue("id")
	if decode(r, &in) != nil || !isUUID(hid) || !isUUID(in.PlantID) || (in.UserID != nil && !isUUID(*in.UserID)) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var owner bool
		if err := tx.QueryRow(ctx, `select mtj_household_owner($1)`, hid).Scan(&owner); err != nil {
			return err
		}
		if !owner {
			return apiError{http.StatusForbidden, "not_owner"}
		}
		if in.UserID == nil {
			_, err := tx.Exec(ctx, `delete from household_assignments where household_id = $1 and plant_id = $2`, hid, in.PlantID)
			return err
		}
		var okPlant, okMember bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from records r join households h on h.jungle_id = r.jungle_id
				where h.id = $1 and r.entity = 'plant' and r.id = $2 and not r.deleted),
			exists (select 1 from household_members where household_id = $1 and user_id = $3)`, hid, in.PlantID, *in.UserID).Scan(&okPlant, &okMember); err != nil {
			return err
		}
		if !okPlant || !okMember {
			return apiError{http.StatusNotFound, "not_found"}
		}
		_, err := tx.Exec(ctx, `insert into household_assignments (household_id, plant_id, user_id) values ($1,$2,$3)
			on conflict (household_id, plant_id) do update set user_id = excluded.user_id, assigned_at = now()`, hid, in.PlantID, *in.UserID)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type rotationTurn struct {
	PlantID  string    `json:"plantId"`
	Plant    string    `json:"plant"`
	Due      time.Time `json:"due"`
	Overdue  bool      `json:"overdue"`
	UserID   string    `json:"userId"`
	Assigned bool      `json:"assigned"` // pinned by an owner rather than rotated
}

type rotationLoad struct {
	UserID      string  `json:"userId"`
	DisplayName *string `json:"displayName"`
	Role        string  `json:"role"`
	Waterings30 int     `json:"waterings30d"`
	Upcoming    int     `json:"upcoming"`
}

// GET /v1/households/{id}/rotation?days=7 (1–28): every watering due in the window and who does it.
func (s *Server) householdRotation(w http.ResponseWriter, r *http.Request) {
	ctx, c, hid := r.Context(), claimsOf(r), r.PathValue("id")
	days := 7
	if v := r.URL.Query().Get("days"); v != "" {
		if n, err := parseIntRange(v, 1, 28); err == nil {
			days = n
		} else {
			s.fail(w, r, bad("invalid_request"))
			return
		}
	}
	if !isUUID(hid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	now := s.now().UTC()
	var h householdOut
	var recs []rec
	done := map[string]int{}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var err error
		if h, err = loadHousehold(ctx, tx, c.Sub, hid); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select jungle_id::text, entity, id::text, data, coalesce(updated_by::text, '') from records
			where not deleted and jungle_id = $1 and entity in ('plant', 'care_event')
			and (entity <> 'care_event' or (jsonb_typeof(data->'date') = 'number' and (data->>'date')::float8 > $2))`,
			h.JungleID, float64(now.AddDate(0, 0, -120).Unix()))
		if err != nil {
			return err
		}
		defer rows.Close()
		cut := now.AddDate(0, 0, -30)
		for rows.Next() {
			var x rec
			var by string
			if rows.Scan(&x.jungle, &x.entity, &x.id, &x.data, &by) != nil {
				continue
			}
			recs = append(recs, x)
			if f, ok := num(x.data, "date"); ok && x.entity == "care_event" && str(x.data, "kind") == "water" && epoch(f).After(cut) && by != "" {
				done[by]++
			}
		}
		return rows.Err()
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	loads := make([]rotationLoad, 0, len(h.Members))
	idx := map[string]int{}
	for i, m := range h.Members {
		loads = append(loads, rotationLoad{UserID: m.UserID, DisplayName: m.DisplayName, Role: m.Role, Waterings30: done[m.UserID]})
		idx[m.UserID] = i
	}
	pinned := map[string]string{}
	for _, a := range h.Assignments {
		if _, ok := idx[a.UserID]; ok {
			pinned[a.PlantID] = a.UserID
		}
	}
	end := now.AddDate(0, 0, days)
	var turns []rotationTurn
	for _, p := range schedules(recs, now, s.speciesLookup()) {
		iv := time.Duration(p.Interval * 24 * float64(time.Hour))
		for next := p.NextWater; next.Before(end); next = next.Add(iv) {
			t := rotationTurn{PlantID: p.ID, Plant: p.Name, Due: next, Overdue: next.Before(now)}
			if next.Before(now) {
				next = now // one overdue turn, then the rhythm continues from today
			}
			turns = append(turns, t)
		}
	}
	sort.SliceStable(turns, func(i, j int) bool {
		if !turns[i].Due.Equal(turns[j].Due) {
			return turns[i].Due.Before(turns[j].Due)
		}
		return turns[i].PlantID < turns[j].PlantID
	})
	for i := range turns {
		if u, ok := pinned[turns[i].PlantID]; ok {
			turns[i].UserID, turns[i].Assigned = u, true
			loads[idx[u]].Upcoming++
		}
	}
	for i := range turns {
		if turns[i].Assigned || len(loads) == 0 {
			continue
		}
		best := 0
		for j := range loads {
			a, b := loads[j].Waterings30+loads[j].Upcoming, loads[best].Waterings30+loads[best].Upcoming
			if a < b || (a == b && loads[j].UserID < loads[best].UserID) {
				best = j
			}
		}
		turns[i].UserID = loads[best].UserID
		loads[best].Upcoming++
	}
	if turns == nil {
		turns = []rotationTurn{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"householdId": hid, "from": now, "to": end, "members": loads, "turns": turns})
}

func parseIntRange(v string, lo, hi int) (int, error) {
	n := 0
	for _, ch := range v {
		if ch < '0' || ch > '9' || n > 1000 {
			return 0, errors.New("range")
		}
		n = n*10 + int(ch-'0')
	}
	if n < lo || n > hi {
		return 0, errors.New("range")
	}
	return n, nil
}
