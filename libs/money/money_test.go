package money

import (
	"math"
	"testing"
)

func TestNewValidatesCurrency(t *testing.T) {
	cases := []struct {
		currency string
		valid    bool
	}{
		{"USD", true},
		{"usd", false},
		{"INR", true},
		{"US", false},
		{"USDD", false},
		{"", false},
		{"12D", false},
	}
	for _, c := range cases {
		_, err := New(100, c.currency)
		if c.valid && err != nil {
			t.Errorf("New(100, %q): unexpected error %v", c.currency, err)
		}
		if !c.valid && err == nil {
			t.Errorf("New(100, %q): expected error, got none", c.currency)
		}
	}
}

func TestAdd(t *testing.T) {
	a := MustNew(150, "USD")
	b := MustNew(250, "USD")
	got, err := a.Add(b)
	if err != nil {
		t.Fatal(err)
	}
	if want := int64(400); got.Minor() != want {
		t.Errorf("Add: got %d, want %d", got.Minor(), want)
	}
}

func TestAddRejectsCurrencyMismatch(t *testing.T) {
	a := MustNew(1, "USD")
	b := MustNew(1, "INR")
	if _, err := a.Add(b); err != ErrCurrencyMismatch {
		t.Errorf("Add: got %v, want ErrCurrencyMismatch", err)
	}
}

func TestAddDetectsOverflow(t *testing.T) {
	a := MustNew(math.MaxInt64, "USD")
	b := MustNew(1, "USD")
	if _, err := a.Add(b); err != ErrOverflow {
		t.Errorf("Add: got %v, want ErrOverflow", err)
	}
}

func TestSub(t *testing.T) {
	a := MustNew(150, "USD")
	b := MustNew(250, "USD")
	got, err := a.Sub(b)
	if err != nil {
		t.Fatal(err)
	}
	if want := int64(-100); got.Minor() != want {
		t.Errorf("Sub: got %d, want %d", got.Minor(), want)
	}
	if !got.IsNegative() {
		t.Error("Sub: result should be negative")
	}
}

func TestMul(t *testing.T) {
	a := MustNew(25, "USD")
	got, err := a.Mul(7)
	if err != nil {
		t.Fatal(err)
	}
	if want := int64(175); got.Minor() != want {
		t.Errorf("Mul: got %d, want %d", got.Minor(), want)
	}
}

func TestMulDetectsOverflow(t *testing.T) {
	a := MustNew(math.MaxInt64, "USD")
	if _, err := a.Mul(2); err != ErrOverflow {
		t.Errorf("Mul: got %v, want ErrOverflow", err)
	}
}

func TestNegAndAbs(t *testing.T) {
	a := MustNew(-500, "USD")
	if !a.Neg().Equal(MustNew(500, "USD")) {
		t.Error("Neg: unexpected result")
	}
	if !a.Abs().Equal(MustNew(500, "USD")) {
		t.Error("Abs: unexpected result")
	}
}

func TestCmp(t *testing.T) {
	a := MustNew(100, "USD")
	b := MustNew(200, "USD")
	c, _ := a.Cmp(b)
	if c != -1 {
		t.Error("Cmp: want -1")
	}
	c, _ = b.Cmp(a)
	if c != 1 {
		t.Error("Cmp: want 1")
	}
	c, _ = a.Cmp(MustNew(100, "USD"))
	if c != 0 {
		t.Error("Cmp: want 0")
	}
}

func TestString(t *testing.T) {
	cases := []struct {
		minor int64
		want  string
	}{
		{0, "0.00 USD"},
		{5, "0.05 USD"},
		{12345, "123.45 USD"},
		{-12345, "-123.45 USD"},
		{100000000, "1000000.00 USD"},
	}
	for _, c := range cases {
		got := MustNew(c.minor, "USD").String()
		if got != c.want {
			t.Errorf("String(%d): got %q, want %q", c.minor, got, c.want)
		}
	}
}

func TestEquality(t *testing.T) {
	a := MustNew(100, "USD")
	b := MustNew(100, "USD")
	if !a.Equal(b) {
		t.Error("Equal: expected true")
	}
	if a.Equal(MustNew(101, "USD")) {
		t.Error("Equal: expected false for different amounts")
	}
	if a.Equal(MustNew(100, "INR")) {
		t.Error("Equal: expected false for different currencies")
	}
}
