package tokens

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrWeakSigningKey = errors.New("tokens: signing key must be at least 32 bytes")
	ErrInvalidToken   = errors.New("tokens: invalid token")
)

type Manager struct {
	signingKey []byte
	issuer     string
	accessTTL  time.Duration
	refreshTTL time.Duration
}

func NewManager(signingKey []byte, issuer string, accessTTL, refreshTTL time.Duration) (*Manager, error) {
	if len(signingKey) < 32 {
		return nil, ErrWeakSigningKey
	}
	return &Manager{
		signingKey: signingKey,
		issuer:     issuer,
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}, nil
}

type claims struct {
	TokenType string `json:"typ"`
	jwt.RegisteredClaims
}

func (m *Manager) Issue(ctx context.Context, userID domain.UserID, tokenType string) (string, error) {
	ttl := m.accessTTL
	if tokenType == application.TokenTypeRefresh {
		ttl = m.refreshTTL
	}
	jti, err := newTokenID()
	if err != nil {
		return "", err
	}
	now := time.Now()
	c := claims{
		TokenType: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   string(userID),
			Issuer:    m.issuer,
			ID:        jti,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(m.signingKey)
}

func (m *Manager) Verify(ctx context.Context, token string) (*application.TokenClaims, error) {
	parsed, err := jwt.ParseWithClaims(token, &claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return m.signingKey, nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}), jwt.WithIssuer(m.issuer))
	if err != nil {
		return nil, ErrInvalidToken
	}
	c, ok := parsed.Claims.(*claims)
	if !ok || !parsed.Valid || c.TokenType == "" || c.Subject == "" {
		return nil, ErrInvalidToken
	}
	return &application.TokenClaims{
		UserID:    domain.UserID(c.Subject),
		TokenType: c.TokenType,
	}, nil
}

func newTokenID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}