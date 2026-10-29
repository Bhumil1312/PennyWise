package application

type ErrorKind int

const (
	KindInvalidArgument ErrorKind = iota
	KindNotFound
	KindAlreadyExists
	KindUnauthenticated
	KindInternal
)

type Error struct {
	Kind    ErrorKind
	Message string
}

func (e *Error) Error() string {
	return e.Message
}

func E(kind ErrorKind, message string) *Error {
	return &Error{Kind: kind, Message: message}
}
