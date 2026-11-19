package api

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	Auth  *pgxpool.Pool // mtj_auth: identities, sessions, store intake
	App   *pgxpool.Pool // mtj_app: RLS-scoped user data
	Admin *pgxpool.Pool // mtj_admin: dashboard reads
}

func OpenDB(ctx context.Context, c Config) (*DB, error) {
	open := func(dsn string, max int32) (*pgxpool.Pool, error) {
		cfg, err := pgxpool.ParseConfig(dsn)
		if err != nil {
			return nil, err
		}
		cfg.MaxConns = max
		cfg.ConnConfig.RuntimeParams["statement_timeout"] = "10000"
		cfg.ConnConfig.RuntimeParams["application_name"] = "mtj-api"
		return pgxpool.NewWithConfig(ctx, cfg)
	}
	a, err := open(c.AuthDSN, 6)
	if err != nil {
		return nil, err
	}
	p, err := open(c.AppDSN, 16)
	if err != nil {
		return nil, err
	}
	ad, err := open(c.AdminDSN, 3)
	if err != nil {
		return nil, err
	}
	return &DB{Auth: a, App: p, Admin: ad}, nil
}

// AsUser runs fn in a transaction with mtj.uid set, so row-level security applies to every statement.
func (d *DB) AsUser(ctx context.Context, uid string, fn func(pgx.Tx) error) error {
	return pgx.BeginFunc(ctx, d.App, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select set_config('mtj.uid', $1, true)`, uid); err != nil {
			return err
		}
		return fn(tx)
	})
}

func isNoRows(err error) bool { return errors.Is(err, pgx.ErrNoRows) }
