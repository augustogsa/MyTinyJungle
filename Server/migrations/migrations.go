// Package migrations embeds the SQL files and applies each exactly once, in order, in a transaction.
package migrations

import (
	"context"
	"embed"
	"errors"
	"io/fs"
	"log/slog"
	"sort"

	"github.com/jackc/pgx/v5"
)

//go:embed *.sql
var files embed.FS

func Apply(ctx context.Context, dsn string, log *slog.Logger) error {
	if dsn == "" {
		return errors.New("MTJ_OWNER_DSN not set")
	}
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	if _, err := conn.Exec(ctx, `create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())`); err != nil {
		return err
	}
	names, _ := fs.Glob(files, "*.sql")
	sort.Strings(names)
	for _, n := range names {
		var done bool
		if err := conn.QueryRow(ctx, `select exists (select 1 from schema_migrations where name = $1)`, n).Scan(&done); err != nil {
			return err
		}
		if done {
			continue
		}
		sql, _ := files.ReadFile(n)
		if err := pgx.BeginFunc(ctx, conn, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, string(sql)); err != nil {
				return err
			}
			_, err := tx.Exec(ctx, `insert into schema_migrations (name) values ($1)`, n)
			return err
		}); err != nil {
			return errors.New(n + ": " + err.Error())
		}
		log.Info("migrated", "file", n)
	}
	return nil
}
