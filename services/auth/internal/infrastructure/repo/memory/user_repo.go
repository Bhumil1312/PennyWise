package memory

import (
	"context"
	"sync"

	"github.com/Bhumil1312/PennyWise/services/auth/internal/application"
	"github.com/Bhumil1312/PennyWise/services/auth/internal/domain"
)

type UserRepository struct {
	mu      sync.RWMutex
	users   map[domain.UserID]*domain.User
	byEmail map[domain.Email]domain.UserID
}

func NewUserRepository() *UserRepository {
	return &UserRepository{
		users:   make(map[domain.UserID]*domain.User),
		byEmail: make(map[domain.Email]domain.UserID),
	}
}

func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.byEmail[user.Email()]; ok {
		return application.ErrUserAlreadyExists
	}
	r.users[user.ID()] = user
	r.byEmail[user.Email()] = user.ID()
	return nil
}

func (r *UserRepository) FindByEmail(ctx context.Context, email domain.Email) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	id, ok := r.byEmail[email]
	if !ok {
		return nil, application.ErrUserNotFound
	}
	return r.users[id], nil
}

func (r *UserRepository) FindByID(ctx context.Context, id domain.UserID) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	user, ok := r.users[id]
	if !ok {
		return nil, application.ErrUserNotFound
	}
	return user, nil
}