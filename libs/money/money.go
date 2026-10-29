package money

import (
	"errors"
	"fmt"
	"regexp"
)

var currencyPattern = regexp.MustCompile(`^[A-Z]{3}$`)

var (
	ErrInvalidCurrency = errors.New("money: currency must be a 3-letter ISO 4217 code")
	ErrCurrencyMismatch = errors.New("money: currency mismatch")
	ErrOverflow = errors.New("money: integer overflow")
)

type Money struct {
	minor    int64
	currency string
}

func New(minor int64, currency string) (Money, error) {
	if !currencyPattern.MatchString(currency) {
		return Money{}, ErrInvalidCurrency
	}
	return Money{minor: minor, currency: currency}, nil
}

func MustNew(minor int64, currency string) Money {
	m, err := New(minor, currency)
	if err != nil {
		panic(err)
	}
	return m
}

func (m Money) Minor() int64 {
	return m.minor
}

func (m Money) Currency() string {
	return m.currency
}

func (m Money) IsZero() bool {
	return m.minor == 0
}

func (m Money) IsNegative() bool {
	return m.minor < 0
}

func (m Money) Equal(o Money) bool {
	return m == o
}

func (m Money) Cmp(o Money) (int, error) {
	if m.currency != o.currency {
		return 0, ErrCurrencyMismatch
	}
	switch {
	case m.minor < o.minor:
		return -1, nil
	case m.minor > o.minor:
		return 1, nil
	default:
		return 0, nil
	}
}

func (m Money) Neg() Money {
	return Money{minor: -m.minor, currency: m.currency}
}

func (m Money) Abs() Money {
	if m.minor < 0 {
		return m.Neg()
	}
	return m
}

func (m Money) Add(o Money) (Money, error) {
	if m.currency != o.currency {
		return Money{}, ErrCurrencyMismatch
	}
	sum := m.minor + o.minor
	if (sum > m.minor) != (o.minor > 0) {
		return Money{}, ErrOverflow
	}
	return Money{minor: sum, currency: m.currency}, nil
}

func (m Money) Sub(o Money) (Money, error) {
	return m.Add(o.Neg())
}

func (m Money) Mul(factor int64) (Money, error) {
	if m.minor == 0 || factor == 0 {
		return Money{minor: 0, currency: m.currency}, nil
	}
	product := m.minor * factor
	if product/factor != m.minor {
		return Money{}, ErrOverflow
	}
	return Money{minor: product, currency: m.currency}, nil
}

func (m Money) String() string {
	sign := ""
	value := m.minor
	if value < 0 {
		sign = "-"
		value = -value
	}
	return fmt.Sprintf("%s%d.%02d %s", sign, value/100, value%100, m.currency)
}
