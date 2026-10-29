package application

import (
	"context"
	"errors"
	"regexp"
	"strings"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
)

var (
	letterPattern = regexp.MustCompile(`[A-Za-z]`)
	digitPattern  = regexp.MustCompile(`[0-9]`)
)

type AuthService struct {
	users  UserRepository
	hasher PasswordHasher
	tokens TokenManager
}

func NewAuthService(users UserRepository, hasher PasswordHasher, tokens TokenManager) *AuthService {
	return &AuthService{users: users, hasher: hasher, tokens: tokens}
}

func (s *AuthService) Register(ctx context.Context, email, password, name string) (*domain.User, string, string, error) {
	email = normalizeEmail(email)
	if email == "" {
		return nil, "", "", E(KindInvalidArgument, "email is required")
	}
	if err := validatePassword(password); err != nil {
		return nil, "", "", err
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, "", "", E(KindInvalidArgument, "name is required")
	}
	if _, err := s.users.FindByEmail(ctx, domain.Email(email)); err == nil {
		return nil, "", "", E(KindAlreadyExists, ErrUserAlreadyExists.Error())
	}
	hash, err := s.hasher.Hash(ctx, password)
	if err != nil {
		return nil, "", "", E(KindInternal, "failed to secure password")
	}
	id, err := domain.GenerateUserID()
	if err != nil {
		return nil, "", "", E(KindInternal, "failed to generate user id")
	}
	user, err := domain.NewUser(id, domain.Email(email), name, hash)
	if err != nil {
		return nil, "", "", E(KindInternal, err.Error())
	}
	if err := s.users.Create(ctx, user); err != nil {
		if errors.Is(err, ErrUserAlreadyExists) {
			return nil, "", "", E(KindAlreadyExists, ErrUserAlreadyExists.Error())
		}
		return nil, "", "", E(KindInternal, "failed to persist user")
	}
	access, refresh, err := s.issueTokens(ctx, user.ID())
	if err != nil {
		return nil, "", "", err
	}
	return user, access, refresh, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*domain.User, string, string, error) {
	email = normalizeEmail(email)
	if email == "" || password == "" {
		return nil, "", "", E(KindInvalidArgument, "email and password are required")
	}
	user, err := s.users.FindByEmail(ctx, domain.Email(email))
	if err != nil {
		return nil, "", "", E(KindUnauthenticated, "invalid credentials")
	}
	ok, err := s.hasher.Verify(ctx, user.PasswordHash(), password)
	if err != nil || !ok {
		return nil, "", "", E(KindUnauthenticated, "invalid credentials")
	}
	access, refresh, err := s.issueTokens(ctx, user.ID())
	if err != nil {
		return nil, "", "", err
	}
	return user, access, refresh, nil
}

func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (string, string, error) {
	claims, err := s.tokens.Verify(ctx, refreshToken)
	if err != nil || claims.TokenType != TokenTypeRefresh {
		return "", "", E(KindUnauthenticated, "invalid refresh token")
	}
	if _, err := s.users.FindByID(ctx, claims.UserID); err != nil {
		return "", "", E(KindUnauthenticated, "invalid refresh token")
	}
	return s.issueTokens(ctx, claims.UserID)
}

func (s *AuthService) Logout(ctx context.Context, refreshToken string) error {
	return nil
}

func (s *AuthService) GetUser(ctx context.Context, id domain.UserID) (*domain.User, error) {
	user, err := s.users.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			return nil, E(KindNotFound, ErrUserNotFound.Error())
		}
		return nil, E(KindInternal, "failed to load user")
	}
	return user, nil
}

func (s *AuthService) issueTokens(ctx context.Context, userID domain.UserID) (string, string, error) {
	access, err := s.tokens.Issue(ctx, userID, TokenTypeAccess)
	if err != nil {
		return "", "", E(KindInternal, "failed to issue access token")
	}
	refresh, err := s.tokens.Issue(ctx, userID, TokenTypeRefresh)
	if err != nil {
		return "", "", E(KindInternal, "failed to issue refresh token")
	}
	return access, refresh, nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validatePassword(password string) error {
	if len(password) < 8 {
		return E(KindInvalidArgument, "password must be at least 8 characters")
	}
	if !letterPattern.MatchString(password) || !digitPattern.MatchString(password) {
		return E(KindInvalidArgument, "password must contain at least one letter and one digit")
	}
	return nil
}
