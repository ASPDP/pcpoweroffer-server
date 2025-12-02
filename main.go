package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"sync"
	"time"

	"go.bug.st/serial"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	pb "pcpoweroffer-server/api/gen"
)

const (
	configFile = "config.cfg"
	port       = ":50051"
	maxRetries = 10
)

type server struct {
	pb.UnimplementedPowerControlServer
	configPassword string
	failCount      int
	mu             sync.Mutex
}

func (s *server) SendPassword(ctx context.Context, req *pb.PasswordRequest) (*pb.PasswordResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.failCount >= maxRetries {
		// Service should exit if retries exceeded
		go func() {
			time.Sleep(100 * time.Millisecond)
			os.Exit(1)
		}()
		return &pb.PasswordResponse{Success: false, Message: "Service locked due to too many attempts"}, nil
	}

	// Validate input: non-repeated numbers, min 4
	if !isValidPasswordFormat(req.Password) {
		return &pb.PasswordResponse{Success: false, Message: "Invalid password format"}, nil
	}

	if req.Password == s.configPassword {
		// Success
		err := sendSerialCommand()
		if err != nil {
			log.Printf("Failed to send serial command: %v", err)
			return &pb.PasswordResponse{Success: false, Message: "Password correct, but hardware error"}, nil
		}
		// Reset fail count on success? The requirement says "when service restarted tryies must be reset to 0".
		// It doesn't explicitly say to reset on success, but usually that's implied. 
		// However, strict reading: "when password mismatched more thn 10 times in day - exit service".
		// If I succeed, I probably shouldn't count towards the 10 failures.
		// I won't reset failCount on success unless asked, but I won't increment it either.
		return &pb.PasswordResponse{Success: true, Message: "Access granted"}, nil
	} else {
		// Failure
		s.failCount++
		log.Printf("Password mismatch. Attempt %d/%d", s.failCount, maxRetries)
		if s.failCount >= maxRetries {
			log.Println("Max retries reached. Exiting service.")
			go func() {
				time.Sleep(100 * time.Millisecond)
				os.Exit(1)
			}()
			return &pb.PasswordResponse{Success: false, Message: "Too many failed attempts. Service exiting."}, nil
		}
		return &pb.PasswordResponse{Success: false, Message: "Incorrect password"}, nil
	}
}

func isValidPasswordFormat(pwd string) bool {
	if len(pwd) < 4 {
		return false
	}
	seen := make(map[rune]bool)
	for _, char := range pwd {
		if char < '0' || char > '9' {
			return false // Not a number
		}
		if seen[char] {
			return false // Repeated number
		}
		seen[char] = true
	}
	return true
}

func sendSerialCommand() error {
	mode := &serial.Mode{
		BaudRate: 9600,
		Parity:   serial.NoParity,
		DataBits: 8,
		StopBits: serial.OneStopBit,
	}
	portName := "/dev/ttyACM0"

	// Check if we are on Windows for local testing (optional, but good for user experience)
	if _, err := os.Stat(portName); os.IsNotExist(err) {
		// If /dev/ttyACM0 doesn't exist, maybe we are testing?
		// But user asked for Linux server. I will stick to the requirement.
		// However, to avoid immediate crash if they run it on Windows without the port:
		// log.Printf("Warning: %s not found", portName)
	}

	p, err := serial.Open(portName, mode)
	if err != nil {
		return err
	}
	defer p.Close()

	_, err = p.Write([]byte("0"))
	return err
}

func loadConfig() (string, error) {
	file, err := os.Open(configFile)
	if err != nil {
		return "", err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "password=") {
			return strings.TrimPrefix(line, "password="), nil
		}
	}
	return "", fmt.Errorf("password not found in config")
}

func main() {
	// Load config
	pwd, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterPowerControlServer(s, &server{configPassword: pwd})
	reflection.Register(s)

	log.Printf("Server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
