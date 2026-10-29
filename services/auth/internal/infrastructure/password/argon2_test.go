package password

import (
	"context"
	"testing"
)

func TestHashVerifyRoundTrip(t *testing.T) {
	h := NewArgon2idHasher()
	ctx := context.Background()
	encoded, err := h.Hash(ctx, "correct-horse-9")
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}
	if len(encoded) < 40 {
		t.Errorf("Hash: encoded too short: %q", encoded)
	}
	ok, err := h.Verify(ctx, encoded, "correct-horse-9")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if !ok {
		t.Error("Verify: expected true for correct password")
	}
	ok, err = h.Verify(ctx, encoded, "wrong-password")
	if err != nil {
		t.Fatalf("Verify wrong password: %v", err)
	}
	if ok {
		t.Error("Verify: expected false for wrong password")
	}
}

func TestVerifyRejectsMalformedHash(t *testing.T) {
	h := NewArgon2idHasher()
	cases := []string{
		"",
		"plaintext",
		"$argon2id$v=19$m=65536,t=1,p=4$bWlzc2luZ3NhbHQ",
		"$argon2id$v=18$m=65536,t=1,p=4$c2FsdHNhbHRzYWx0c2FsdHNhbHRzYWx0c2FsdA$c2FsdHNhbHRzYWx0c2FsdHNhbHRzYWx0c2FsdHNhbHQ",
	}
	for _, c := range cases {
		if _, err := h.Verify(context.Background(), c, "password"); err == nil {
			t.Errorf("Verify(%q): expected error, got none", c)
		}
	}
}

func TestHashesAreUnique(t *testing.T) {
	h := NewArgon2idHasher()
	ctx := context.Background()
	a, _ := h.Hash(ctx, "same-password-1")
	b, _ := h.Hash(ctx, "same-password-1")
	if a == b {
		t.Error("Hash: expected unique salts to produce different hashes")
	}
}