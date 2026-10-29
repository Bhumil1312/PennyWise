package grpc

import (
	"context"
	"log/slog"
	"net"

	authv1 "github.com/Bhumil1312/PennyWise/gen/go/pennywise/auth/v1"
	healthv1 "github.com/Bhumil1312/PennyWise/gen/go/pennywise/health/v1"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/config"
	"go.uber.org/fx"
	"google.golang.org/grpc"
)

func NewGRPCServer(svc *application.AuthService, version string) *grpc.Server {
	srv := grpc.NewServer()
	s := NewServer(svc, version)
	authv1.RegisterAuthServiceServer(srv, s)
	healthv1.RegisterHealthServiceServer(srv, s)
	return srv
}

func RunGRPCServer(lc fx.Lifecycle, srv *grpc.Server, cfg config.Config, log *slog.Logger) {
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			lis, err := net.Listen("tcp", cfg.GRPCAddress)
			if err != nil {
				return err
			}
			log.Info("grpc server listening", "address", cfg.GRPCAddress)
			go func() {
				if err := srv.Serve(lis); err != nil {
					log.Error("grpc server stopped", "error", err)
				}
			}()
			return nil
		},
		OnStop: func(ctx context.Context) error {
			srv.GracefulStop()
			return nil
		},
	})
}