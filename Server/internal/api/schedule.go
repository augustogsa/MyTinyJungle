package api

import (
	"encoding/json"
	"time"
)

// Server-side watering schedule, shared by the digest, the household rotation and the admin metrics.
// Interval: the plant's learned dry days, else the species' dryMax, else 7. The next watering is the last
// one plus the interval, corrected by the newest soil moisture reading taken after it:
//   care_event.moisture {method: meter|finger, value}: meter 1–10 (1–3 dry, 4–7 slightly moist, 8–10 wet, as the apps map it), finger 0 dry,
//   1 slightly moist, 2 wet. A soilCheck's legacy soil field (dry|slightlyMoist|wet) counts as a finger reading.
//   dry → due at the reading; slightly moist → reading + ¼ interval; wet → no earlier than reading + ½ interval.

type moisture struct {
	Method string   `json:"method"`
	Value  *float64 `json:"value"`
}

// validMoisture reports whether a care event's moisture field is absent or well formed.
func validMoisture(data json.RawMessage) bool {
	var ev struct {
		Moisture *json.RawMessage `json:"moisture"`
	}
	if json.Unmarshal(data, &ev) != nil || ev.Moisture == nil || string(*ev.Moisture) == "null" {
		return true
	}
	var m moisture
	if json.Unmarshal(*ev.Moisture, &m) != nil || m.Value == nil {
		return false
	}
	v := *m.Value
	switch m.Method {
	case "meter":
		return v >= 1 && v <= 10
	case "finger":
		return v == 0 || v == 1 || v == 2
	}
	return false
}

// soilLevel: 0 dry, 1 slightly moist, 2 wet, -1 no reading.
func soilLevel(ev map[string]any) int {
	if m, ok := ev["moisture"].(map[string]any); ok {
		v, ok := m["value"].(float64)
		if !ok {
			return -1
		}
		switch str(m, "method") {
		case "meter":
			switch {
			case v <= 3:
				return 0
			case v > 7:
				return 2
			}
			return 1
		case "finger":
			if v >= 0 && v <= 2 {
				return int(v)
			}
		}
		return -1
	}
	switch str(ev, "soil") {
	case "dry":
		return 0
	case "slightlyMoist":
		return 1
	case "wet":
		return 2
	}
	return -1
}

type plantSched struct {
	ID, Jungle, Name, Species string
	Data                      map[string]any
	Interval                  float64 // days between waterings
	Created                   time.Time
	LastWater, LastFeed       time.Time
	LastEvent                 time.Time
	NextWater                 time.Time
	FeedWeeks, RepotYears     float64
	Moisture                  int // newest reading after the last watering, -1 none
}

// schedules builds the watering schedule of every live (not archived) plant in recs.
func schedules(recs []rec, now time.Time, care func(string) speciesCare) map[string]*plantSched {
	out := map[string]*plantSched{}
	for _, r := range recs {
		if r.entity != "plant" || boolean(r.data, "isArchived") {
			continue
		}
		sc := care(str(r.data, "speciesID"))
		p := &plantSched{ID: r.id, Jungle: r.jungle, Name: str(r.data, "name"), Species: str(r.data, "speciesID"), Data: r.data,
			Interval: sc.dry, FeedWeeks: sc.feedWeeks, RepotYears: sc.repotYears, Created: now, Moisture: -1}
		if v, ok := num(r.data, "learnedDryDays"); ok && v > 0 {
			p.Interval = v
		}
		if p.Interval <= 0 {
			p.Interval = 7
		}
		p.Interval = max(p.Interval, 1)
		if f, ok := num(r.data, "createdAt"); ok {
			p.Created = epoch(f)
		}
		out[r.id] = p
	}
	type reading struct {
		at    time.Time
		level int
	}
	readings := map[string]reading{}
	for _, r := range recs {
		if r.entity != "care_event" {
			continue
		}
		p := out[str(r.data, "plantID")]
		if p == nil {
			continue
		}
		f, _ := num(r.data, "date")
		at := epoch(f)
		if at.After(p.LastEvent) {
			p.LastEvent = at
		}
		switch str(r.data, "kind") {
		case "water":
			if at.After(p.LastWater) {
				p.LastWater = at
			}
		case "feed":
			if at.After(p.LastFeed) {
				p.LastFeed = at
			}
		}
		if lv := soilLevel(r.data); lv >= 0 && at.After(readings[p.ID].at) {
			readings[p.ID] = reading{at, lv}
		}
	}
	for _, p := range out {
		base := p.LastWater
		if base.IsZero() {
			base = p.Created
		}
		iv := time.Duration(p.Interval * 24 * float64(time.Hour))
		p.NextWater = base.Add(iv)
		if rd, ok := readings[p.ID]; ok && rd.at.After(p.LastWater) && !rd.at.After(now.Add(time.Hour)) {
			p.Moisture = rd.level
			switch rd.level {
			case 0:
				if rd.at.Before(p.NextWater) {
					p.NextWater = rd.at
				}
			case 1:
				p.NextWater = rd.at.Add(iv / 4)
			case 2:
				if t := rd.at.Add(iv / 2); t.After(p.NextWater) {
					p.NextWater = t
				}
			}
		}
	}
	return out
}
