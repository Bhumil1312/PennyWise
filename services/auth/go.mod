module github.com/Bhumil1312/PennyWise/services/auth

go 1.25.0

require (
	github.com/Bhumil1312/PennyWise/gen/go v0.0.0
	github.com/Bhumil1312/PennyWise/libs/observability v0.0.0
	github.com/golang-jwt/jwt/v5 v5.3.1
	go.uber.org/fx v1.24.0
	golang.org/x/crypto v0.55.0
	google.golang.org/grpc v1.83.0
)

require (
	go.uber.org/dig v1.19.0 // indirect
	go.uber.org/multierr v1.10.0 // indirect
	go.uber.org/zap v1.26.0 // indirect
	golang.org/x/net v0.57.0 // indirect
	golang.org/x/sys v0.47.0 // indirect
	golang.org/x/text v0.41.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260526163538-3dc84a4a5aaa // indirect
	google.golang.org/protobuf v1.36.11 // indirect
)

replace (
	github.com/Bhumil1312/PennyWise/gen/go => ../../gen/go
	github.com/Bhumil1312/PennyWise/libs/observability => ../../libs/observability
)
