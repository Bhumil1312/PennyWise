package config

import (
	"errors"
	"os"
	"time"
)

type Config struct {
	Env             string
	GRPCAddress     string
	JWTSecret       string
	Issuer          string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Env:             getenv("AUTH_ENV", "development"),
		GRPCAddress:     getenv("AUTH_GRPC_ADDRESS", "0.0.0.0:50051"),
		JWTSecret:       os.Getenv("AUTH_JWT_SECRET"),
		Issuer:          getenv("AUTH_ISSUER", "pennywise-auth"),
		AccessTokenTTL:  15 * time.Minute,
		RefreshTokenTTL: 30 * 24 * time.Hour,
	}
	if cfg.JWTSecret == "" {
		return Config{}, errors.New("AUTH_JWT_SECRET is required (min 32 bytes)")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}