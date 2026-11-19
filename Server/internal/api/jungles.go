package api

import (
	"crypto/rand"
	"errors"
	"math/big"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type jungleOut struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	IsPersonal bool       `json:"isPersonal"`
	OwnerID    string     `json:"ownerId"`
	Role       string     `json:"role"`
	Until      *time.Time `json:"until"`
	Members    []member   `json:"members"`
}

type member struct {
	UserID      string     `json:"userId"`
	DisplayName *string    `json:"displayName"`
	Role        string     `json:"role"`
	Until       *time.Time `json:"until"`
}

// jungles lists every jungle the user can reach, creating the personal one on first call.
func (s *Server) jungles(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	out := []jungleOut{}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var personal string
		err := tx.QueryRow(ctx, `select id from jungles where owner_id = $1 and is_personal`, c.Sub).Scan(&personal)
		if isNoRows(err) {
			if err := tx.QueryRow(ctx, `insert into jungles (owner_id, is_personal) values ($1, true) returning id`, c.Sub).Scan(&personal); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into jungle_members (jungle_id, user_id, role) values ($1,$2,'owner')`, personal, c.Sub); err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		rows, _ := tx.Query(ctx, `select j.id, j.name, j.is_personal, j.owner_id, m.role, m.until
			from jungles j join jungle_members m on m.jungle_id = j.id and m.user_id = $1
			where m.until is null or m.until > now() order by j.is_personal desc, j.created_at`, c.Sub)
		js, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (jungleOut, error) {
			j := jungleOut{Members: []member{}}
			return j, row.Scan(&j.ID, &j.Name, &j.IsPersonal, &j.OwnerID, &j.Role, &j.Until)
		})
		if err != nil {
			return err
		}
		for i := range js {
			rows, _ := tx.Query(ctx, `select user_id, display_name, role, until from mtj_jungle_members($1)`, js[i].ID)
			ms, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (member, error) {
				var m member
				return m, row.Scan(&m.UserID, &m.DisplayName, &m.Role, &m.Until)
			})
			if err != nil {
				return err
			}
			js[i].Members = append(js[i].Members, ms...)
		}
		out = js
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"jungles": out})
}

func (s *Server) createJungle(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name string `json:"name"`
	}
	if err := decode(r, &in); err != nil || len(in.Name) > 60 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	var id string
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `insert into jungles (owner_id, name) values ($1,$2) returning id`, c.Sub, in.Name).Scan(&id); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into jungle_members (jungle_id, user_id, role) values ($1,$2,'owner')`, id, c.Sub)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"id": id})
}

const inviteAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func inviteCode() string {
	b := make([]byte, 10)
	for i := range b {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(inviteAlphabet))))
		b[i] = inviteAlphabet[n.Int64()]
	}
	return string(b)
}

func (s *Server) createInvite(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role  string     `json:"role"`
		Until *time.Time `json:"until"`
	}
	if err := decode(r, &in); err != nil || (in.Role != "member" && in.Role != "sitter") || (in.Role == "sitter" && in.Until == nil) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c, jid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(jid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	code := inviteCode()
	expires := s.now().Add(7 * 24 * time.Hour)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `insert into invites (code, jungle_id, role, until, created_by, expires_at)
			select $1, id, $3, $4, $5, $6 from jungles where id = $2 and owner_id = $5`, code, jid, in.Role, in.Until, c.Sub, expires)
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

func (s *Server) redeemInvite(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	var jid string
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select mtj_redeem_invite($1)`, r.PathValue("code")).Scan(&jid)
	})
	var pe *pgconn.PgError
	if errors.As(err, &pe) && pe.Message == "invite_invalid" {
		writeErr(w, http.StatusNotFound, "invite_invalid")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"jungleId": jid})
}

// updateMember: owner changes a role or a sitter's end date (make someone sit for a week, extend).
func (s *Server) updateMember(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role  string     `json:"role"`
		Until *time.Time `json:"until"`
	}
	if err := decode(r, &in); err != nil || (in.Role != "member" && in.Role != "sitter") {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update jungle_members set role = $3, until = $4 where jungle_id = $1 and user_id = $2 and role <> 'owner'`,
			r.PathValue("id"), r.PathValue("uid"), in.Role, in.Until)
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

// removeMember: owner removes someone, or a member leaves (uid = self).
func (s *Server) removeMember(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from jungle_members where jungle_id = $1 and user_id = $2 and role <> 'owner'`,
			r.PathValue("id"), r.PathValue("uid"))
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
