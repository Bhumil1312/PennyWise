package observability

import (
	"log/slog"
	"os"
	"strings"
)

func New(service, env string) *slog.Logger {
	level := slog.LevelInfo
	switch strings.ToLower(env) {
	case "development", "dev":
		level = slog.LevelDebug
	case "staging":
		level = slog.LevelInfo
	case "production", "prod":
		level = slog.LevelInfo
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
	})).With("service", service)
}
