.PHONY: all gen build clean

all: gen build

gen:
	mkdir -p api/gen
	protoc --proto_path=api --go_out=api/gen --go_opt=paths=source_relative \
	--go-grpc_out=api/gen --go-grpc_opt=paths=source_relative \
	power_control.proto

build:
	go build -o pcpoweroffer-server main.go

clean:
	rm -f pcpoweroffer-server
	rm -f api/gen/*.go
