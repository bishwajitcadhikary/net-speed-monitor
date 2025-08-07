# GitHub Actions Setup

This document explains how to set up GitHub Actions for building and releasing the Net Speed Monitor macOS application.

## Workflows

### 1. Build Workflow (`build.yml`)
- **Trigger**: Push to main/develop branches, pull requests, or manual dispatch
- **Purpose**: Build the application for testing and development
- **Features**: 
  - Builds both Debug and Release configurations
  - No code signing required
  - Uploads build artifacts for 7 days

### 2. Build and Release Workflow (`build-and-release.yml`)
- **Trigger**: Push tags starting with 'v' (e.g., v1.0.0) or manual dispatch
- **Purpose**: Build, sign, notarize, and release the application
- **Features**:
  - Code signing with Developer ID
  - Apple notarization
  - DMG creation
  - GitHub release creation

## Required GitHub Secrets

For the release workflow to work, you need to set up the following secrets in your GitHub repository:

### 1. Code Signing Secrets
- `P12_BASE64`: Base64-encoded P12 certificate file
- `P12_PASSWORD`: Password for the P12 certificate
- `DEVELOPER_ID`: Your Developer ID (e.g., "Your Name (TEAM_ID)")
- `DEVELOPER_TEAM_ID`: Your Apple Developer Team ID

### 2. Apple Notarization Secrets
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for your Apple ID

## Setting Up Secrets

### 1. Export P12 Certificate
```bash
# Export your certificate from Keychain Access
security export -k login.keychain -t identities -f pkcs12 -o certificate.p12
```

### 2. Convert to Base64
```bash
# Convert P12 to base64
base64 -i certificate.p12 | pbcopy
```

### 3. Add Secrets to GitHub
1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Add each secret with the appropriate name and value

## Usage

### For Development/Testing
The build workflow will run automatically on:
- Push to main or develop branches
- Pull requests to main branch
- Manual dispatch from GitHub Actions tab

### For Releases
1. **Automatic Release**: Push a tag starting with 'v'
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Manual Release**: 
   - Go to Actions tab in GitHub
   - Select "Build and Release" workflow
   - Click "Run workflow"
   - Enter the version number
   - Click "Run workflow"

## Build Artifacts

### Build Workflow
- Archive file (.xcarchive) containing the built application
- Available for 7 days
- No code signing

### Release Workflow
- Signed and notarized DMG file
- Archive file (.xcarchive)
- Available for 30 days
- Automatically creates a GitHub release

## Troubleshooting

### Common Issues

1. **Code Signing Errors**
   - Ensure P12 certificate is valid and not expired
   - Check that DEVELOPER_TEAM_ID matches your certificate
   - Verify P12_PASSWORD is correct

2. **Notarization Failures**
   - Check APPLE_ID and APPLE_APP_SPECIFIC_PASSWORD
   - Ensure app meets Apple's notarization requirements
   - Check that code signing is properly configured

3. **Build Failures**
   - Verify XcodeGen is generating the project correctly
   - Check that all dependencies are properly configured
   - Ensure macOS deployment target is set correctly

### Debugging
- Check the Actions tab in GitHub for detailed logs
- Download build artifacts to inspect the built application
- Use the Debug build for testing without code signing

## Security Notes

- Never commit secrets to the repository
- Use app-specific passwords for Apple ID
- Regularly rotate certificates and passwords
- Keep P12 certificates secure and backed up

## Next Steps

1. Set up the required secrets in your GitHub repository
2. Test the build workflow with a push to main branch
3. Create a test release by pushing a tag
4. Verify the DMG works on target systems
