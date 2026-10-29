package password

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	saltLen    = 16
	keyLen     = 32
	timeCost   = 1
	memoryCost = 64 * 1024
	parallel   = 4
)

var ErrInvalidHash = errors.New("password: invalid encoded hash")

type Argon2idHasher struct{}

func NewArgon2idHasher() *Argon2idHasher {
	return &Argon2idHasher{}
}

func (h *Argon2idHasher) Hash(ctx context.Context, password string) (string, error) {
	salt := make([]byte, saltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key := argon2.IDKey([]byte(password), salt, timeCost, memoryCost, parallel, keyLen)
	encoded := fmt.Sprintf(
		"$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version, memoryCost, timeCost, parallel,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key),
	)
	return encoded, nil
}

func (h *Argon2idHasher) Verify(ctx context.Context, encodedHash, password string) (bool, error) {
	params, salt, key, err := decodeHash(encodedHash)
	if err != nil {
		return false, err
	}
	candidate := argon2.IDKey([]byte(password), salt, params.time, params.memory, params.threads, uint32(len(key)))
	return subtle.ConstantTimeCompare(candidate, key) == 1, nil
}

type hashParams struct {
	memory  uint32
	time    uint32
	threads uint8
}

func decodeHash(encoded string) (hashParams, []byte, []byte, error) {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil || version != argon2.Version {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	var memory, time uint32
	var threads uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &time, &threads); err != nil {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	if memory < 8*1024 || time < 1 || threads < 1 {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	salt, err := base64.RawStdEncoding.Strict().DecodeString(parts[4])
	if err != nil {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	key, err := base64.RawStdEncoding.Strict().DecodeString(parts[5])
	if err != nil {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	if len(salt) != saltLen || len(key) != keyLen {
		return hashParams{}, nil, nil, ErrInvalidHash
	}
	return hashParams{memory: memory, time: time, threads: threads}, salt, key, nil
}