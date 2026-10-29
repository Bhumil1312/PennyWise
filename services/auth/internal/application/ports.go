package application

import (
	"context"
	"errors"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrUserAlreadyExists = errors.New("email already registered")
)

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	FindByEmail(ctx context.Context, email domain.Email) (*domain.User, error)
	FindByID(ctx context.Context, id domain.UserID) (*domain.User, error)
}

type PasswordHasher interface {
	Hash(ctx context.Context, password string) (string, error)
	Verify(ctx context.Context, encodedHash, password string) (bool, error)
}

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

type TokenClaims struct {
	UserID    domain.UserID
	TokenType string
}

type TokenManager interface {
	Issue(ctx context.Context, userID domain.UserID, tokenType string) (string, error)
	Verify(ctx context.Context, token string) (*TokenClaims, error)
}
