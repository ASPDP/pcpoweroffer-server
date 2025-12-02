# Power Control gRPC API

This document describes the gRPC API for the PC Power Offer Server.

## Service Definition

The service is defined in `api/power_control.proto`.

### Service: `PowerControl`

#### Method: `SendPassword`

Sends a password to the server to trigger the power control action (sending '0' to the serial port).

- **Request**: `PasswordRequest`
  - `password` (string): A sequence of non-repeated numbers (minimum 4 digits).
    - Example: "0192837465"
    - Invalid: "011" (repeated), "123" (too short), "abc" (non-numeric).

- **Response**: `PasswordResponse`
  - `success` (bool): True if the password was correct and the command was executed.
  - `message` (string): A descriptive message about the result (e.g., "Access granted", "Incorrect password", "Service locked").

## Logic Details

- **Validation**: The password must consist of at least 4 digits, and no digit can be repeated.
- **Rate Limiting**: If the password is incorrect more than 10 times in a single day (since service start), the service will lock and exit. It must be restarted to reset the counter.
- **Serial Port**: On success, the server writes the character '0' to `/dev/ttyACM0` (9600 baud, 8N1).

## Android Implementation Tips

1.  **Dependencies**: Use `grpc-java` or `grpc-kotlin`.
2.  **Proto Compilation**: Copy `api/power_control.proto` to your Android project and configure the Protobuf Gradle plugin to generate the client code.
3.  **Channel**: Create a `ManagedChannel` pointing to the server's IP and port (default 50051).
4.  **Stub**: Create a `PowerControlBlockingStub` (or async) to call `SendPassword`.

```java
// Example Java/Kotlin usage concept
ManagedChannel channel = ManagedChannelBuilder.forAddress("SERVER_IP", 50051)
    .usePlaintext() // If not using TLS
    .build();

PowerControlGrpc.PowerControlBlockingStub stub = PowerControlGrpc.newBlockingStub(channel);

PasswordRequest request = PasswordRequest.newBuilder()
    .setPassword("0192837465")
    .build();

try {
    PasswordResponse response = stub.sendPassword(request);
    if (response.getSuccess()) {
        // Handle success
    } else {
        // Handle failure: response.getMessage()
    }
} catch (StatusRuntimeException e) {
    // Handle gRPC error
}
```
