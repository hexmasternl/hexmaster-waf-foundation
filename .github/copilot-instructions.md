# Copilot Instructions

- This repository defines an Azure landing zone and related deployment automation.
- Prefer Bicep for infrastructure as code and keep modules aligned with the OpenSpec change in `openspec/changes/azure-landing-zone-foundation/`.
- Preserve the current architecture direction: low-cost defaults, hub-and-spoke networking, P2S VPN operator access, central ACR, and GitHub runners on Azure Container Apps Jobs.
- Treat the hub as a platform network and keep application workloads in spoke VNets.
- Avoid introducing premium Azure networking services by default unless the requirement explicitly calls for them.
- When answering Azure, Bicep, GitHub Actions, or Microsoft platform questions, prefer the Microsoft Learn MCP for current official guidance before relying on general web knowledge.
