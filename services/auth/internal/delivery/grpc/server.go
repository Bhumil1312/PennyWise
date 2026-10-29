package grpc

import (
	"context"
	"errors"

	authv1 "github.com/Bhumil1312/PennyWise/gen/go/pennywise/auth/v1"
	healthv1 "github.com/Bhumil1312/PennyWise/gen/go/pennywise/health/v1"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Server struct {
	authv1.UnimplementedAuthServiceServer
	healthv1.UnimplementedHealthServiceServer
	svc     *application.AuthService
	version string
}

func NewServer(svc *application.AuthService, version string) *Server {
	return &Server{svc: svc, version: version}
}

func (s *Server) Register(ctx context.Context, req *authv1.RegisterRequest) (*authv1.RegisterResponse, error) {
	user, access, refresh, err := s.svc.Register(ctx, req.GetEmail(), req.GetPassword(), req.GetName())
	if err != nil {
		return nil, toGRPCError(err)
	}
	return &authv1.RegisterResponse{
		User:         toProtoUser(user),
		AccessToken:  access,
		RefreshToken: refresh,
	}, nil
}

func (s *Server) Login(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginResponse, error) {
	user, access, refresh, err := s.svc.Login(ctx, req.GetEmail(), req.GetPassword())
	if err != nil {
		return nil, toGRPCError(err)
	}
	return &authv1.LoginResponse{
		User:         toProtoUser(user),
		AccessToken:  access,
		RefreshToken: refresh,
	}, nil
}

func (s *Server) Refresh(ctx context.Context, req *authv1.RefreshRequest) (*authv1.RefreshResponse, error) {
	access, refresh, err := s.svc.Refresh(ctx, req.GetRefreshToken())
	if err != nil {
		return nil, toGRPCError(err)
	}
	return &authv1.RefreshResponse{
		AccessToken:  access,
		RefreshToken: refresh,
	}, nil
}

func (s *Server) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	if err := s.svc.Logout(ctx, req.GetRefreshToken()); err != nil {
		return nil, toGRPCError(err)
	}
	return &authv1.LogoutResponse{}, nil
}

func (s *Server) GetUser(ctx context.Context, req *authv1.GetUserRequest) (*authv1.GetUserResponse, error) {
	user, err := s.svc.GetUser(ctx, domain.UserID(req.GetUserId()))
	if err != nil {
		return nil, toGRPCError(err)
	}
	return &authv1.GetUserResponse{User: toProtoUser(user)}, nil
}

func (s *Server) Check(ctx context.Context, req *healthv1.CheckRequest) (*healthv1.CheckResponse, error) {
	return &healthv1.CheckResponse{
		Status:  healthv1.Status_STATUS_SERVING,
		Service: "auth-service",
		Version: s.version,
	}, nil
}

func toProtoUser(u *domain.User) *authv1.User {
	return &authv1.User{
		Id:        string(u.ID()),
		Email:     string(u.Email()),
		Name:      u.Name(),
		CreatedAt: u.CreatedAt().Format("2006-01-02T15:04:05Z07:00"),
	}
}

func toGRPCError(err error) error {
	var appErr *application.Error
	if errors.As(err, &appErr) {
		switch appErr.Kind {
		case application.KindInvalidArgument:
			return status.Error(codes.InvalidArgument, appErr.Message)
		case application.KindNotFound:
			return status.Error(codes.NotFound, appErr.Message)
		case application.KindAlreadyExists:
			return status.Error(codes.AlreadyExists, appErr.Message)
		case application.KindUnauthenticated:
			return status.Error(codes.Unauthenticated, appErr.Message)
		default:
			return status.Error(codes.Internal, "internal error")
		}
	}
	return status.Error(codes.Internal, "internal error")
}