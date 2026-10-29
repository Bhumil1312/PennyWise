package domain

import (
	"crypto/rand"
	"errors"
	"fmt"
	"time"
)

var (
	ErrInvalidUserID       = errors.New("domain: invalid user id")
	ErrInvalidEmail        = errors.New("domain: invalid email")
	ErrInvalidName         = errors.New("domain: invalid name")
	ErrInvalidPasswordHash = errors.New("domain: invalid password hash")
)

type UserID string

func GenerateUserID() (UserID, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return UserID(fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])), nil
}

type Email string

func (e Email) IsValid() bool {
	return e != ""
}

type User struct {
	id           UserID
	email        Email
	name         string
	passwordHash string
	createdAt    time.Time
}

func NewUser(id UserID, email Email, name, passwordHash string) (*User, error) {
	if id == "" {
		return nil, ErrInvalidUserID
	}
	if !email.IsValid() {
		return nil, ErrInvalidEmail
	}
	if name == "" {
		return nil, ErrInvalidName
	}
	if passwordHash == "" {
		return nil, ErrInvalidPasswordHash
	}
	return &User{
		id:           id,
		email:        email,
		name:         name,
		passwordHash: passwordHash,
		createdAt:    time.Now().UTC(),
	}, nil
}

func RestoreUser(id UserID, email Email, name, passwordHash string, createdAt time.Time) (*User, error) {
	if id == "" {
		return nil, ErrInvalidUserID
	}
	if passwordHash == "" {
		return nil, ErrInvalidPasswordHash
	}
	return &User{
		id:           id,
		email:        email,
		name:         name,
		passwordHash: passwordHash,
		createdAt:    createdAt,
	}, nil
}

func (u *User) ID() UserID            { return u.id }
func (u *User) Email() Email          { return u.email }
func (u *User) Name() string          { return u.name }
func (u *User) PasswordHash() string  { return u.passwordHash }
func (u *User) CreatedAt() time.Time  { return u.createdAt }
