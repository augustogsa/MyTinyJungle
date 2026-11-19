// mtj-api: My Tiny Jungle API server and its maintenance commands.
//
//	mtj-api serve            run the API (unix socket or loopback)
//	mtj-api migrate          apply migrations (MTJ_OWNER_DSN)
//	mtj-api keygen <kid>     write a new Ed25519 signing key to MTJ_KEYS_DIR
//	mtj-api purge            erase accounts deleted more than 30 days ago (timer)
//	mtj-api test-token <email>  create/find a test user and print an access token (root-only; integration tests)
package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/simpleappscompany/mytinyjungle/server/internal/api"
	"github.com/simpleappscompany/mytinyjungle/server/migrations"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mtj-api serve|migrate|keygen|purge|test-token")
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "serve":
		err = serve(log)
	case "migrate":
		err = migrations.Apply(context.Background(), os.Getenv("MTJ_OWNER_DSN"), log)
	case "keygen":
		err = keygen()
	case "purge":
		err = purge(log)
	case "test-token":
		err = testToken()
	default:
		err = errors.New("unknown command")
	}
	if err != nil {
		log.Error("fatal", "err", err.Error())
		os.Exit(1)
	}
}

func serve(log *slog.Logger) error {
	cfg, err := api.LoadConfig()
	if err != nil {
		return err
	}
	priv, pubs, err := api.LoadKeys(cfg.KeysDir, cfg.SigningKid)
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()
	db, err := api.OpenDB(ctx, cfg)
	if err != nil {
		return err
	}
	srv := &http.Server{
		Handler:           api.New(cfg, db, priv, pubs, log).Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	var ln net.Listener
	if cfg.Socket != "" {
		_ = os.Remove(cfg.Socket)
		if ln, err = net.Listen("unix", cfg.Socket); err != nil {
			return err
		}
		// Only the web server's group (the service's primary group) may connect.
		if err := os.Chmod(cfg.Socket, 0o660); err != nil {
			return err
		}
	} else if ln, err = net.Listen("tcp", cfg.Addr); err != nil {
		return err
	}
	go func() {
		<-ctx.Done()
		sctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(sctx)
	}()
	log.Info("listening", "on", ln.Addr().String(), "release", cfg.Release)
	if err := srv.Serve(ln); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

func keygen() error {
	if len(os.Args) < 3 {
		return errors.New("keygen <kid>")
	}
	dir := os.Getenv("MTJ_KEYS_DIR")
	if dir == "" {
		dir = "/opt/mtj/secrets/keys"
	}
	seed := make([]byte, ed25519.SeedSize)
	if _, err := rand.Read(seed); err != nil {
		return err
	}
	path := filepath.Join(dir, os.Args[2]+".key")
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o640)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(hex.EncodeToString(seed) + "\n")
	fmt.Println("wrote", path)
	return err
}

// purge erases accounts whose deletion grace period is over, with the jungles they own and their photos.
func purge(log *slog.Logger) error {
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, os.Getenv("MTJ_OWNER_DSN"))
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	rows, _ := conn.Query(ctx, `select j.id::text from jungles j join users u on u.id = j.owner_id
		where u.deleted_at < now() - interval '30 days'`)
	jungles, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return err
	}
	tag, err := conn.Exec(ctx, `delete from users where deleted_at < now() - interval '30 days'`)
	if err != nil {
		return err
	}
	mediaDir := os.Getenv("MTJ_MEDIA_DIR")
	if mediaDir == "" {
		mediaDir = "/var/lib/mtj/media"
	}
	for _, j := range jungles {
		_ = os.RemoveAll(filepath.Join(mediaDir, j))
	}
	_, _ = conn.Exec(ctx, `delete from sessions where expires_at < now()`)
	_, _ = conn.Exec(ctx, `delete from invites where expires_at < now() - interval '30 days'`)
	_, _ = conn.Exec(ctx, `delete from store_notifications where received_at < now() - interval '400 days'`)
	_, _ = conn.Exec(ctx, `delete from audit_log where at < now() - interval '400 days'`)
	_, _ = conn.Exec(ctx, `delete from diagnostics where created_at < now() - interval '90 days'`)
	if tag.RowsAffected() > 0 {
		_, _ = conn.Exec(ctx, `insert into audit_log (actor, action, detail) values ('system','account.purge',$1)`,
			map[string]int64{"accounts": tag.RowsAffected()})
	}
	log.Info("purge", "accounts", tag.RowsAffected(), "jungles", len(jungles))
	return nil
}

func testToken() error {
	if len(os.Args) < 3 {
		return errors.New("test-token <email>")
	}
	cfg, err := api.LoadConfig()
	if err != nil {
		return err
	}
	priv, pubs, err := api.LoadKeys(cfg.KeysDir, cfg.SigningKid)
	if err != nil {
		return err
	}
	ctx := context.Background()
	db, err := api.OpenDB(ctx, cfg)
	if err != nil {
		return err
	}
	tok, err := api.New(cfg, db, priv, pubs, slog.Default()).TestToken(ctx, os.Args[2])
	if err != nil {
		return err
	}
	fmt.Println(tok)
	return nil
}
