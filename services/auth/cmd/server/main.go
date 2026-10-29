package main

import (
	"log/slog"

	"github.com/Bhumil1312/PennyWise/libs/observability"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/config"
	delivery "github.com/Bhumil1312/PennyWise/services/auth/internal/delivery/grpc"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/infrastructure/password"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/infrastructure/repo/memory"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/infrastructure/tokens"
	"go.uber.org/fx"
	"google.golang.org/grpc"
)

const version = "0.1.0"

func main() {
	fx.New(
		fx.Provide(
			config.Load,
			func(cfg config.Config) *slog.Logger {
				return observability.New("auth-service", cfg.Env)
			},
			func() application.UserRepository {
				return memory.NewUserRepository()
			},
			func() application.PasswordHasher {
				return password.NewArgon2idHasher()
			},
			func(cfg config.Config) (application.TokenManager, error) {
				return tokens.NewManager([]byte(cfg.JWTSecret), cfg.Issuer, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
			},
			application.NewAuthService,
			func(svc *application.AuthService) *grpc.Server {
				return delivery.NewGRPCServer(svc, version)
			},
		),
		fx.Invoke(delivery.RunGRPCServer),
	).Run()
}