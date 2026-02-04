#!/bin/bash
# Setup AWS Credentials for CTF Deployment

echo "🔑 AWS Credentials Setup for CTF Fortinet Deployment"
echo "=================================================="

echo ""
echo "1️⃣ Get fresh AWS credentials:"
echo "   aws sts get-session-token --duration-seconds 14400"
echo ""

echo "2️⃣ Set environment variables:"
echo "   export AWS_ACCESS_KEY_ID=\"YOUR_ACCESS_KEY\""
echo "   export AWS_SECRET_ACCESS_KEY=\"YOUR_SECRET_KEY\""
echo "   export AWS_SESSION_TOKEN=\"YOUR_SESSION_TOKEN\"  # If using STS"
echo "   export AWS_DEFAULT_REGION=\"us-east-1\""
echo ""

echo "3️⃣ Test credentials:"
echo "   aws sts get-caller-identity"
echo ""

echo "4️⃣ Run CTF deployment:"
echo "   terraform plan -out=ctf-phase2.tfplan"
echo "   terraform apply ctf-phase2.tfplan"
echo ""

echo "🎯 Expected deployment:"
echo "   - 2 FortiGate teams"
echo "   - 1 FortiAnalyzer (Phase 2)"
echo "   - 1 CTFd platform"
echo "   - 1 Utility server (flag server)"
echo "   - Total cost: ~$2.00 for 4h event"
echo ""

echo "📊 Post-deployment access:"
echo "   - FortiGate: https://[IP] (ctfplayer/CTFPlayer2026!)"
echo "   - FortiAnalyzer: https://[IP] (admin/FortiCTF2026!)"
echo "   - CTFd: http://[IP] (admin/CTFAdmin2026!)"
echo "   - Flag server: http://[IP]:8080"