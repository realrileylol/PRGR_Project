/**
 * Standalone K-LD2 Radar Test Program (C++)
 * ==========================================
 * Tests the K-LD2 Doppler radar sensor independently from the GUI.
 *
 * Model: K-LD2-RFB-00H-02 (RFBEAM MICROWAVE GMBH)
 * - 38400 baud UART communication
 * - ASCII command protocol
 * - Separates approaching (club) from receding (ball) targets
 *
 * Compile:
 *   g++ -O2 -o test_radar test_radar.cpp -lpthread
 *
 * Usage:
 *   ./test_radar                     # Basic monitoring (ball mode)
 *   ./test_radar --mode club         # Club-based trigger
 *   ./test_radar --debug             # Show all raw data
 *   ./test_radar --port /dev/ttyAMA0 # Specific port
 *   ./test_radar --help              # Show help
 */

#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <csignal>
#include <chrono>
#include <thread>
#include <vector>
#include <sstream>
#include <iomanip>

// Linux serial
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>
#include <sys/select.h>

// ============================================================================
// Configuration
// ============================================================================

struct Config {
    std::string port = "";              // Auto-detect if empty
    std::string mode = "ball";          // "ball" or "club"
    double ballThreshold = 12.0;        // mph
    double clubThreshold = 50.0;        // mph
    bool debug = false;
    bool interactive = false;
    int duration = 0;                   // 0 = indefinite
};

// ============================================================================
// K-LD2 Radar Class
// ============================================================================

class KLD2Radar {
public:
    static constexpr int BAUD_RATE = 38400;
    static constexpr const char* CMD_SET_SAMPLING = "$S0405\r\n";
    static constexpr const char* CMD_GET_SPEED = "$C01\r\n";

private:
    int fd_ = -1;
    Config config_;

    // State machine
    bool inSwing_ = false;
    double maxClubSpeed_ = 0.0;
    bool ballDetected_ = false;

    // Statistics
    int totalReadings_ = 0;
    int impactsDetected_ = 0;
    double maxClubSeen_ = 0.0;
    double maxBallSeen_ = 0.0;

    volatile bool running_ = false;

public:
    explicit KLD2Radar(const Config& config) : config_(config) {}

    ~KLD2Radar() {
        close();
    }

    bool open() {
        std::vector<std::string> ports;

        if (!config_.port.empty()) {
            ports.push_back(config_.port);
        } else {
            ports = {"/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"};
        }

        for (const auto& port : ports) {
            std::cout << "Trying K-LD2 on " << port << "..." << std::endl;

            fd_ = ::open(port.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
            if (fd_ < 0) {
                std::cout << "  ✗ " << port << " failed: " << strerror(errno) << std::endl;
                continue;
            }

            // Configure serial port
            struct termios tty;
            memset(&tty, 0, sizeof(tty));

            if (tcgetattr(fd_, &tty) != 0) {
                std::cout << "  ✗ tcgetattr failed: " << strerror(errno) << std::endl;
                ::close(fd_);
                fd_ = -1;
                continue;
            }

            // 38400 baud, 8N1
            cfsetispeed(&tty, B38400);
            cfsetospeed(&tty, B38400);

            tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;  // 8-bit
            tty.c_cflag &= ~PARENB;                       // No parity
            tty.c_cflag &= ~CSTOPB;                       // 1 stop bit
            tty.c_cflag &= ~CRTSCTS;                      // No flow control
            tty.c_cflag |= CLOCAL | CREAD;                // Enable receiver

            tty.c_iflag &= ~(IXON | IXOFF | IXANY);       // No software flow control
            tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);

            tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);  // Raw mode
            tty.c_oflag &= ~OPOST;                            // Raw output

            tty.c_cc[VMIN] = 0;
            tty.c_cc[VTIME] = 1;  // 100ms timeout

            if (tcsetattr(fd_, TCSANOW, &tty) != 0) {
                std::cout << "  ✗ tcsetattr failed: " << strerror(errno) << std::endl;
                ::close(fd_);
                fd_ = -1;
                continue;
            }

            std::cout << "  ✓ Connected on " << port << " @ " << BAUD_RATE << " baud" << std::endl;
            return true;
        }

        std::cout << "\n❌ K-LD2 radar not found!" << std::endl;
        std::cout << "   Check wiring: GPIO14 (RXD) → Radar TX, GPIO15 (TXD) → Radar RX" << std::endl;
        return false;
    }

    bool configure() {
        if (fd_ < 0) return false;

        std::this_thread::sleep_for(std::chrono::milliseconds(200));

        std::cout << "Configuring sampling rate (20480 Hz)..." << std::endl;

        if (writeCmd(CMD_SET_SAMPLING) < 0) {
            std::cout << "  ✗ Failed to send config command" << std::endl;
            return false;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(300));

        // Read any response
        char buf[256];
        int n = ::read(fd_, buf, sizeof(buf) - 1);
        if (n > 0 && config_.debug) {
            buf[n] = '\0';
            std::cout << "  Config response: " << buf << std::endl;
        }

        std::cout << "  ✓ Radar configured" << std::endl;
        return true;
    }

    void close() {
        running_ = false;
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
            std::cout << "Serial port closed" << std::endl;
        }
    }

    void stop() {
        running_ = false;
    }

    void runMonitor() {
        std::cout << "\n" << std::string(60, '=') << std::endl;
        std::cout << "K-LD2 RADAR MONITOR" << std::endl;
        std::cout << std::string(60, '=') << std::endl;
        std::cout << "Trigger mode: " << (config_.mode == "ball" ? "BALL" : "CLUB") << std::endl;

        if (config_.mode == "ball") {
            std::cout << "Ball trigger threshold: " << config_.ballThreshold << " mph" << std::endl;
        } else {
            std::cout << "Club trigger threshold: " << config_.clubThreshold << " mph" << std::endl;
        }

        std::cout << "Debug: " << (config_.debug ? "ON" : "OFF") << std::endl;
        std::cout << std::string(60, '-') << std::endl;
        std::cout << "Press Ctrl+C to stop\n" << std::endl;

        running_ = true;
        auto startTime = std::chrono::steady_clock::now();
        std::string buffer;

        while (running_) {
            // Send poll command
            if (writeCmd(CMD_GET_SPEED) < 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                continue;
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(50));

            // Read response
            char buf[256];
            int n = ::read(fd_, buf, sizeof(buf) - 1);
            if (n > 0) {
                buf[n] = '\0';
                buffer += buf;

                // Process complete lines
                size_t pos;
                while ((pos = buffer.find('\n')) != std::string::npos) {
                    std::string line = buffer.substr(0, pos);
                    buffer = buffer.substr(pos + 1);

                    // Trim
                    while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) {
                        line.pop_back();
                    }

                    if (!line.empty() && line[0] != '$' && line[0] != '@') {
                        processLine(line);
                    }
                }
            }

            // Check duration
            if (config_.duration > 0) {
                auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
                    std::chrono::steady_clock::now() - startTime).count();
                if (elapsed >= config_.duration) {
                    break;
                }
            }
        }

        printSummary();
    }

    void runInteractive() {
        std::cout << "\n" << std::string(60, '=') << std::endl;
        std::cout << "K-LD2 INTERACTIVE TEST MODE" << std::endl;
        std::cout << std::string(60, '=') << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  r  - Read single speed measurement" << std::endl;
        std::cout << "  m  - Monitor continuously (Ctrl+C to stop)" << std::endl;
        std::cout << "  c  - Send custom command" << std::endl;
        std::cout << "  s  - Show statistics" << std::endl;
        std::cout << "  q  - Quit" << std::endl;
        std::cout << std::string(60, '-') << std::endl;

        std::string cmd;
        while (true) {
            std::cout << "\nCommand> ";
            std::getline(std::cin, cmd);

            if (cmd == "q") break;

            if (cmd == "r") {
                writeCmd(CMD_GET_SPEED);
                std::this_thread::sleep_for(std::chrono::milliseconds(100));

                char buf[256];
                int n = ::read(fd_, buf, sizeof(buf) - 1);
                if (n > 0) {
                    buf[n] = '\0';
                    std::cout << "  Response: " << buf << std::endl;
                } else {
                    std::cout << "  No data received" << std::endl;
                }
            }
            else if (cmd == "m") {
                runMonitor();
            }
            else if (cmd == "c") {
                std::cout << "  Enter command (e.g., $C01): ";
                std::string custom;
                std::getline(std::cin, custom);

                if (!custom.empty()) {
                    if (custom[0] != '$') custom = "$" + custom;
                    custom += "\r\n";

                    ::write(fd_, custom.c_str(), custom.length());
                    std::this_thread::sleep_for(std::chrono::milliseconds(300));

                    char buf[256];
                    int n = ::read(fd_, buf, sizeof(buf) - 1);
                    if (n > 0) {
                        buf[n] = '\0';
                        std::cout << "  Response: " << buf << std::endl;
                    } else {
                        std::cout << "  No response" << std::endl;
                    }
                }
            }
            else if (cmd == "s") {
                printSummary();
            }
            else {
                std::cout << "  Unknown command. Use r/m/c/s/q" << std::endl;
            }
        }
    }

private:
    int writeCmd(const char* cmd) {
        return ::write(fd_, cmd, strlen(cmd));
    }

    void processLine(const std::string& line) {
        // Parse: approaching;receding;app_mag;rec_mag;
        std::vector<int> parts;
        std::stringstream ss(line);
        std::string token;

        while (std::getline(ss, token, ';')) {
            if (!token.empty()) {
                try {
                    parts.push_back(std::stoi(token));
                } catch (...) {
                    if (config_.debug) {
                        std::cout << "  Parse error: " << line << std::endl;
                    }
                    return;
                }
            }
        }

        if (parts.size() < 4) return;

        int approachingSpeed = parts[0];
        int recedingSpeed = parts[1];
        int approachingMag = parts[2];
        int recedingMag = parts[3];

        totalReadings_++;

        // Track max speeds
        if (approachingSpeed > maxClubSeen_) maxClubSeen_ = approachingSpeed;
        if (recedingSpeed > maxBallSeen_) maxBallSeen_ = recedingSpeed;

        // Debug output
        if (config_.debug && (approachingSpeed > 0 || recedingSpeed > 0)) {
            std::cout << "  ";
            if (approachingSpeed > 0) {
                std::cout << "Club: " << approachingSpeed << " mph (mag " << approachingMag << ")";
            }
            if (approachingSpeed > 0 && recedingSpeed > 0) {
                std::cout << " | ";
            }
            if (recedingSpeed > 0) {
                std::cout << "Ball: " << recedingSpeed << " mph (mag " << recedingMag << ")";
            }
            std::cout << std::endl;
        }

        // === BALL-BASED TRIGGER MODE ===
        if (config_.mode == "ball") {
            if (recedingSpeed >= config_.ballThreshold) {
                if (!ballDetected_) {
                    ballDetected_ = true;
                    impactsDetected_++;
                    std::cout << "🎯 IMPACT! Ball: " << recedingSpeed << " mph" << std::endl;
                }
            } else {
                if (ballDetected_) {
                    ballDetected_ = false;
                    if (config_.debug) {
                        std::cout << "  (Reset - ready for next shot)" << std::endl;
                    }
                }
            }
            return;
        }

        // === CLUB-BASED TRIGGER MODE ===
        if (config_.mode == "club") {
            if (approachingSpeed >= config_.clubThreshold) {
                if (!inSwing_) {
                    inSwing_ = true;
                    maxClubSpeed_ = approachingSpeed;
                    std::cout << "⛳ SWING START: Club " << approachingSpeed << " mph" << std::endl;
                } else {
                    if (approachingSpeed > maxClubSpeed_) {
                        maxClubSpeed_ = approachingSpeed;
                    }
                }
            } else if (inSwing_) {
                impactsDetected_++;
                std::cout << "🏌️ IMPACT! Peak club: " << maxClubSpeed_
                          << " mph → " << approachingSpeed << " mph" << std::endl;
                inSwing_ = false;
                maxClubSpeed_ = 0.0;
            }
        }
    }

    void printSummary() {
        std::cout << "\n" << std::string(60, '-') << std::endl;
        std::cout << "SESSION SUMMARY" << std::endl;
        std::cout << std::string(60, '-') << std::endl;
        std::cout << "Total readings:     " << totalReadings_ << std::endl;
        std::cout << "Impacts detected:   " << impactsDetected_ << std::endl;
        std::cout << "Max club speed:     " << maxClubSeen_ << " mph" << std::endl;
        std::cout << "Max ball speed:     " << maxBallSeen_ << " mph" << std::endl;
        std::cout << std::string(60, '-') << std::endl;
    }
};

// ============================================================================
// Global for signal handling
// ============================================================================

KLD2Radar* g_radar = nullptr;

void signalHandler(int sig) {
    std::cout << "\n\nCaught signal " << sig << ", stopping..." << std::endl;
    if (g_radar) {
        g_radar->stop();
    }
}

// ============================================================================
// Main
// ============================================================================

void printHelp(const char* prog) {
    std::cout << "K-LD2 Doppler Radar Test Tool\n"
              << "Model: K-LD2-RFB-00H-02 (RFBEAM)\n\n"
              << "Usage: " << prog << " [options]\n\n"
              << "Options:\n"
              << "  --mode <ball|club>   Trigger mode (default: ball)\n"
              << "  --ball-threshold N   Ball speed threshold in mph (default: 12)\n"
              << "  --club-threshold N   Club speed threshold in mph (default: 50)\n"
              << "  --port <path>        Serial port (default: auto-detect)\n"
              << "  --debug              Show all raw radar data\n"
              << "  --interactive        Interactive command mode\n"
              << "  --duration N         Run for N seconds (default: indefinite)\n"
              << "  --help               Show this help\n\n"
              << "Examples:\n"
              << "  " << prog << "                        # Basic monitoring\n"
              << "  " << prog << " --debug                # Show all raw data\n"
              << "  " << prog << " --mode club            # Club-based trigger\n"
              << "  " << prog << " --interactive          # Interactive mode\n"
              << std::endl;
}

int main(int argc, char* argv[]) {
    Config config;

    // Parse arguments
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];

        if (arg == "--help" || arg == "-h") {
            printHelp(argv[0]);
            return 0;
        }
        else if (arg == "--debug" || arg == "-d") {
            config.debug = true;
        }
        else if (arg == "--interactive" || arg == "-i") {
            config.interactive = true;
        }
        else if ((arg == "--mode" || arg == "-m") && i + 1 < argc) {
            config.mode = argv[++i];
            if (config.mode != "ball" && config.mode != "club") {
                std::cerr << "Error: mode must be 'ball' or 'club'" << std::endl;
                return 1;
            }
        }
        else if ((arg == "--port" || arg == "-p") && i + 1 < argc) {
            config.port = argv[++i];
        }
        else if ((arg == "--ball-threshold" || arg == "-b") && i + 1 < argc) {
            config.ballThreshold = std::stod(argv[++i]);
        }
        else if ((arg == "--club-threshold" || arg == "-c") && i + 1 < argc) {
            config.clubThreshold = std::stod(argv[++i]);
        }
        else if ((arg == "--duration" || arg == "-t") && i + 1 < argc) {
            config.duration = std::stoi(argv[++i]);
        }
        else {
            std::cerr << "Unknown option: " << arg << std::endl;
            printHelp(argv[0]);
            return 1;
        }
    }

    std::cout << std::string(60, '=') << std::endl;
    std::cout << "K-LD2 DOPPLER RADAR TEST TOOL" << std::endl;
    std::cout << "Model: K-LD2-RFB-00H-02 (RFBEAM)" << std::endl;
    std::cout << std::string(60, '=') << std::endl;

    KLD2Radar radar(config);
    g_radar = &radar;

    // Setup signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);

    // Connect
    if (!radar.open()) {
        return 1;
    }

    // Configure
    if (!radar.configure()) {
        radar.close();
        return 1;
    }

    // Run
    if (config.interactive) {
        radar.runInteractive();
    } else {
        radar.runMonitor();
    }

    radar.close();
    std::cout << "\nDone!" << std::endl;

    return 0;
}
