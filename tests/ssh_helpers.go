//go:build aws

package tests

import (
	"context"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	cryptossh "golang.org/x/crypto/ssh"
)

// rsaKeyPairFromFile loads the PEM-encoded RSA private key the examples write
// to disk and derives the public key from it.
func rsaKeyPairFromFile(path string) (*ssh.KeyPair, error) {
	pemBytes, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	pemBlock, _ := pem.Decode(pemBytes)
	if pemBlock == nil {
		return nil, errors.New("failed to decode PEM block containing private key")
	}

	privKey, err := x509.ParsePKCS1PrivateKey(pemBlock.Bytes)
	if err != nil {
		return nil, err
	}

	sshPubKey, err := cryptossh.NewPublicKey(privKey.Public())
	if err != nil {
		return nil, err
	}

	return &ssh.KeyPair{
		PublicKey:  string(cryptossh.MarshalAuthorizedKey(sshPubKey)),
		PrivateKey: string(pemBytes),
	}, nil
}

// checkSSHToHost connects to the instance as the ubuntu user and checks that
// command output and exit codes come back.
func checkSSHToHost(ctx context.Context, t *testing.T, publicIP string, keyPair *ssh.KeyPair) {
	t.Helper()

	host := &ssh.Host{
		Hostname:    publicIP,
		SshKeyPair:  keyPair,
		SshUserName: "ubuntu",
	}

	// It can take a minute or so for the instance to boot, so retry.
	const maxRetries = 30
	const timeBetweenRetries = 5 * time.Second
	const expectedText = "Hello, World"

	retry.DoWithRetryContext(t, ctx, "SSH to "+publicIP, maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSSHCommandContextE(t, ctx, host, fmt.Sprintf("echo -n '%s'", expectedText))
		if err != nil {
			return "", err
		}
		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("expected SSH command to return %q but got %q", expectedText, actualText)
		}
		return "", nil
	})

	retry.DoWithRetryContext(t, ctx, "SSH to "+publicIP+" with a failing command", maxRetries, timeBetweenRetries, func() (string, error) {
		actualText, err := ssh.CheckSSHCommandContextE(t, ctx, host, fmt.Sprintf("echo -n '%s' && exit 1", expectedText))
		if err == nil {
			return "", errors.New("expected SSH command to return an error but got none")
		}
		if strings.TrimSpace(actualText) != expectedText {
			return "", fmt.Errorf("expected SSH command to return %q but got %q", expectedText, actualText)
		}
		return "", nil
	})
}
