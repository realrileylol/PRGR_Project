// DesignSystem.qml - DARK THEME
pragma Singleton
import QtQuick 2.15

QtObject {
    // DARK THEME COLORS
    readonly property color bg: "#0D1117"              // Main background (dark)
    readonly property color card: "#161B22"            // Card/Panel background
    readonly property color cardHover: "#1C2128"       // Card hover state
    
    // Border & Dividers
    readonly property color edge: "#30363D"            // Border color
    readonly property color divider: "#21262D"         // Subtle divider
    
    // Text Colors
    readonly property color text: "#F0F6FC"            // Primary text (light)
    readonly property color hint: "#8B949E"            // Secondary text / hints
    readonly property color textLight: "#6E7681"       // Tertiary text
    
    // Action Colors
    readonly property color accent: "#1F6FEB"          // Primary action (blue)
    readonly property color accentHover: "#1558B8"     // Accent hover state
    readonly property color success: "#238636"         // Success / confirm (green)
    readonly property color successHover: "#1D6F2F"    // Success hover
    readonly property color danger: "#DA3633"          // Danger / delete (red)
    readonly property color dangerHover: "#B02A2A"     // Danger hover
    readonly property color warning: "#FFB020"         // Warning (orange)
    
    // Status Colors
    readonly property color ok: "#34C759"              // Status: OK/Ready
    readonly property color okBg: "#1B3A1F"            // OK background (dark green)
    readonly property color okBorder: "#2D5F33"        // OK border
    
    // Special Colors
    readonly property color highlight: "#1F6FEB"       // Selection highlight
    readonly property color overlay: "#000000CC"       // Modal overlay (80% black)
    readonly property color successText: "#A6D189"     // Light green for dark bg
    
    // Profile Avatar Colors (same)
    readonly property var profileColors: [
        "#1F6FEB",  // Blue
        "#FF006E",  // Pink
        "#8338EC",  // Purple
        "#FB5607",  // Orange
        "#FFBE0B",  // Yellow
        "#06D6A0"   // Teal
    ]
    
    // Helper functions
    function getProfileColor(name) {
        var colors = ["#1F6FEB", "#FF006E", "#8338EC", "#FB5607", "#FFBE0B", "#06D6A0"]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        return colors[Math.abs(hash) % colors.length]
    }
    
    function getInitials(name) {
        if (!name) return "?"
        var parts = name.trim().split(/\s+/)
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
    }
}