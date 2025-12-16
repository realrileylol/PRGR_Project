#!/bin/bash
# Launch PRGR with console output visible

echo "========================================="
echo "   PRGR Launch Monitor - Console Mode"
echo "========================================="
echo ""
echo "Console output will appear below:"
echo "Press Ctrl+C to quit"
echo ""

# Run with unbuffered Python output
python3 -u main.py 2>&1

echo ""
echo "Application closed."
