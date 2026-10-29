package application_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/infrastructure/repo/memory"
)

type fakeHasher struct{}

func (fakeHasher) Hash(ctx context.Context, password string) (string, error) {
	return "h:" + password, nil
}

func (fakeHasher) Verify(ctx context.Context, encodedHash, password string) (bool, error) {
	return encodedHash == "h:"+password, nil
}

type fakeTokenManager struct{}

func (fakeTokenManager) Issue(ctx context.Context, userID domain.UserID, tokenType string) (string, error) {
	return tokenType + "-token", nil
}

func (fakeTokenManager) Verify(ctx context.Context, token string) (*application.TokenClaims, error) {
	switch token {
	case "access-token":
		return &application.TokenClaims{UserID: "user-1", TokenType: application.TokenTypeAccess}, nil
	case "refresh-token":
		return &application.TokenClaims{UserID: "user-1", TokenType: application.TokenTypeRefresh}, nil
	default:
		return nil, errors.New("invalid token")
	}
}

func newTestService(t *testing.T) (*application.AuthService, *memory.UserRepository) {
	t.Helper()
	repo := memory.NewUserRepository()
	user, err := domain.NewUser("user-1", "a@b.com", "Alice", "h:secret123")
	if err != nil {
		t.Fatal(err)
	}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatal(err)
	}
	svc := application.NewAuthService(repo, fakeHasher{}, fakeTokenManager{})
	return svc, repo
}

func TestRegister(t *testing.T) {
	svc, repo := newTestService(t)
	user, access, refresh, err := svc.Register(context.Background(), "  Alice@Example.com ", "secret123", "Alice")
	if err != nil {
		t.Fatalf("Register: unexpected error %v", err)
	}
	if user.Email() != "alice@example.com" {
		t.Errorf("Register: email not normalized, got %q", user.Email())
	}
	if access != "access-token" || refresh != "refresh-token" {
		t.Errorf("Register: unexpected tokens %q %q", access, refresh)
	}
	if _, err := repo.FindByEmail(context.Background(), "alice@example.com"); err != nil {
		t.Errorf("Register: user not persisted, %v", err)
	}
	if user.CreatedAt().IsZero() {
		t.Error("Register: created_at not set")
	}
}

func TestRegisterDuplicateEmail(t *testing.T) {
	svc, _ := newTestService(t)
	_, _, _, err := svc.Register(context.Background(), "b@c.com", "secret123", "B")
	if err != nil {
		t.Fatal(err)
	}
	_, _, _, err = svc.Register(context.Background(), "b@c.com", "secret123", "B")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindAlreadyExists {
		t.Errorf("Register duplicate: got %v, want KindAlreadyExists", err)
	}
}

func TestRegisterDuplicateSeededEmail(t *testing.T) {
	svc, _ := newTestService(t)
	_, _, _, err := svc.Register(context.Background(), "a@b.com", "secret123", "A")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindAlreadyExists {
		t.Errorf("Register duplicate seeded: got %v, want KindAlreadyExists", err)
	}
}

func TestRegisterWeakPassword(t *testing.T) {
	svc, _ := newTestService(t)
	_, _, _, err := svc.Register(context.Background(), "c@d.com", "short", "C")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindInvalidArgument {
		t.Errorf("Register weak password: got %v, want KindInvalidArgument", err)
	}
}

func TestLoginValid(t *testing.T) {
	svc, _ := newTestService(t)
	user, access, refresh, err := svc.Login(context.Background(), "a@b.com", "secret123")
	if err != nil {
		t.Fatalf("Login: unexpected error %v", err)
	}
	if user.ID() != "user-1" || access != "access-token" || refresh != "refresh-token" {
		t.Errorf("Login: unexpected result")
	}
}

func TestLoginInvalidCredentials(t *testing.T) {
	svc, _ := newTestService(t)
	_, _, _, err := svc.Login(context.Background(), "a@b.com", "wrongpass1")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindUnauthenticated {
		t.Errorf("Login invalid: got %v, want KindUnauthenticated", err)
	}
}

func TestRefresh(t *testing.T) {
	svc, _ := newTestService(t)
	access, refresh, err := svc.Refresh(context.Background(), "refresh-token")
	if err != nil {
		t.Fatalf("Refresh: unexpected error %v", err)
	}
	if access != "access-token" || refresh != "refresh-token" {
		t.Errorf("Refresh: unexpected tokens %q %q", access, refresh)
	}
}

func TestRefreshRejectsAccessToken(t *testing.T) {
	svc, _ := newTestService(t)
	_, _, err := svc.Refresh(context.Background(), "access-token")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindUnauthenticated {
		t.Errorf("Refresh with access token: got %v, want KindUnauthenticated", err)
	}
}

func TestGetUser(t *testing.T) {
	svc, _ := newTestService(t)
	user, err := svc.GetUser(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("GetUser: unexpected error %v", err)
	}
	if user.ID() != "user-1" {
		t.Errorf("GetUser: got %q, want user-1", user.ID())
	}
}

func TestGetUserNotFound(t *testing.T) {
	svc, _ := newTestService(t)
	_, err := svc.GetUser(context.Background(), "missing")
	var appErr *application.Error
	if !errors.As(err, &appErr) || appErr.Kind != application.KindNotFound {
		t.Errorf("GetUser missing: got %v, want KindNotFound", err)
	}
}

func TestUserEntityRestore(t *testing.T) {
	created := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	user, err := domain.RestoreUser("user-9", "z@z.com", "Zoe", "h:abc", created)
	if err != nil {
		t.Fatal(err)
	}
	if !user.CreatedAt().Equal(created) {
		t.Errorf("RestoreUser: got %v, want %v", user.CreatedAt(), created)
	}
	if _, err := domain.RestoreUser("", "z@z.com", "Zoe", "h:abc", created); err != domain.ErrInvalidUserID {
		t.Errorf("RestoreUser: got %v, want ErrInvalidUserID", err)
	}
}