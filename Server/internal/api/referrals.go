package api

import (
	"errors"
	"net/http"
	"os"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

const (
	referralReward  = 30 * 24 * time.Hour
	referralMaxYear = 12
	referralNewUser = 7 * 24 * time.Hour
	referralProduct = "plus.referral"
)

// myReferral returns (creating once) the caller's referral code and link, plus how many friends joined.
func (s *Server) myReferral(w http.ResponseWriter, r *http.Request) {
	ctx, uid := r.Context(), claimsOf(r).Sub
	var code string
	var n int
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select coalesce(referral_code, '') from users where id = $1 for update`, uid).Scan(&code); err != nil {
			return err
		}
		if code == "" {
			code = inviteCode()[:8]
			if _, err := tx.Exec(ctx, `update users set referral_code = $1 where id = $2`, code, uid); err != nil {
				return err
			}
		}
		return tx.QueryRow(ctx, `select count(*) from users where referred_by = $1`, uid).Scan(&n)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"code": code, "url": "https://mytinyjungle.com/r/" + code, "joined": n})
}

// redeemReferral: a new account names the friend who sent the link; both get 30 days of Plus.
func (s *Server) redeemReferral(w http.ResponseWriter, r *http.Request) {
	code := strings.ToUpper(r.PathValue("code"))
	if len(code) != 8 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, uid := r.Context(), claimsOf(r).Sub
	now := s.now()
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		var created time.Time
		var already *string
		if err := tx.QueryRow(ctx, `select created_at, referred_by::text from users where id = $1 for update`, uid).Scan(&created, &already); err != nil {
			return err
		}
		if already != nil {
			return apiError{http.StatusConflict, "already_referred"}
		}
		review := slices.Contains(strings.Split(os.Getenv("MTJ_REVIEW_CODES")+",PLAYREV7", ","), code)
		if now.Sub(created) > referralNewUser && !review { // store reviewers may use older test accounts
			return apiError{http.StatusForbidden, "not_new"}
		}
		var friend string
		if err := tx.QueryRow(ctx, `select id::text from users where referral_code = $1 and deleted_at is null`, code).Scan(&friend); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return apiError{http.StatusNotFound, "not_found"}
			}
			return err
		}
		if friend == uid {
			return apiError{http.StatusForbidden, "own_code"}
		}
		if _, err := tx.Exec(ctx, `update users set referred_by = $1, referred_at = now() where id = $2`, friend, uid); err != nil {
			return err
		}
		var earned int
		if err := tx.QueryRow(ctx, `select count(*) from users where referred_by = $1 and referred_at > now() - interval '1 year'`, friend).Scan(&earned); err != nil {
			return err
		}
		grant := func(user, tag string) error {
			_, err := tx.Exec(ctx, `insert into entitlements (store, original_transaction_id, user_id, product_id, expires_at, status)
				values ('referral', $1, $2, $3, greatest(now(), coalesce((select max(expires_at) from entitlements where user_id = $2 and store = 'referral'), now())) + interval '30 days', 'active')`,
				tag, user, referralProduct)
			return err
		}
		if err := grant(uid, "ref:"+uid); err != nil {
			return err
		}
		if earned <= referralMaxYear && !review {
			return grant(friend, "ref:"+friend+":"+uid)
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	s.entitlementsFor(w, r)
}
