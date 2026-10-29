package tokens

import (
	"context"
	"testing"
	"time"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
)

func newTestManager(t *testing.T) *Manager {
	t.Helper()
	m, err := NewManager([]byte("0123456789abcdef0123456789abcdef"), "pennywise-auth", 15*time.Minute, 30*24*time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func TestIssueVerifyRoundTrip(t *testing.T) {
	m := newTestManager(t)
	ctx := context.Background()
	token, err := m.Issue(ctx, "user-42", application.TokenTypeAccess)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	claims, err := m.Verify(ctx, token)
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if claims.UserID != "user-42" {
		t.Errorf("Verify: got user %q, want user-42", claims.UserID)
	}
	if claims.TokenType != application.TokenTypeAccess {
		t.Errorf("Verify: got type %q, want access", claims.TokenType)
	}
}

func TestVerifyRejectsTamperedToken(t *testing.T) {
	m := newTestManager(t)
	ctx := context.Background()
	token, err := m.Issue(ctx, "user-42", application.TokenTypeAccess)
	if err != nil {
		t.Fatal(err)
	}
	tampered := token[:len(token)-4] + "AAAA"
	if _, err := m.Verify(ctx, tampered); err == nil {
		t.Error("Verify: expected error for tampered token")
	}
}

func TestVerifyRejectsTokenFromOtherKey(t *testing.T) {
	other, err := NewManager([]byte("fedcba9876543210fedcba9876543210"), "pennywise-auth", time.Minute, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	m := newTestManager(t)
	ctx := context.Background()
	token, err := m.Issue(ctx, "user-42", application.TokenTypeAccess)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := other.Verify(ctx, token); err == nil {
		t.Error("Verify: expected error for token signed with different key")
	}
}

func TestVerifyRejectsExpiredToken(t *testing.T) {
	m, err := NewManager([]byte("0123456789abcdef0123456789abcdef"), "pennywise-auth", -time.Minute, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	token, err := m.Issue(context.Background(), "user-42", application.TokenTypeAccess)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.Verify(context.Background(), token); err == nil {
		t.Error("Verify: expected error for expired token")
	}
}

func TestNewManagerRejectsWeakKey(t *testing.T) {
	if _, err := NewManager([]byte("short"), "pennywise-auth", time.Minute, time.Hour); err != ErrWeakSigningKey {
		t.Errorf("NewManager: got %v, want ErrWeakSigningKey", err)
	}
}

func TestManagerSupportsRefreshTokens(t *testing.T) {
	m := newTestManager(t)
	ctx := context.Background()
	token, err := m.Issue(ctx, domain.UserID("user-7"), application.TokenTypeRefresh)
	if err != nil {
		t.Fatal(err)
	}
	claims, err := m.Verify(ctx, token)
	if err != nil {
		t.Fatal(err)
	}
	if claims.TokenType != application.TokenTypeRefresh {
		t.Errorf("Verify: got type %q, want refresh", claims.TokenType)
	}
}