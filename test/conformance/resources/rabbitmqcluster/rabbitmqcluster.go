/*
Copyright 2021 The Knative Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package rabbitmqcluster

import (
	"context"
	"embed"
	"log"
	"time"

	"github.com/kelseyhightower/envconfig"
	"knative.dev/reconciler-test/pkg/feature"
	"knative.dev/reconciler-test/pkg/k8s"
	"knative.dev/reconciler-test/pkg/manifest"

	"k8s.io/apimachinery/pkg/runtime/schema"
)

//go:embed "*.yaml"
var yamls embed.FS

var EnvCfg EnvConfig

type EnvConfig struct {
	RabbitmqServerImage     string `envconfig:"RABBITMQ_SERVER_IMAGE"`
	RabbitmqImagePullSecret string `envconfig:"RABBITMQ_IMAGE_PULL_SECRET"`
}

func init() {
	// Process EventingGlobal.
	if err := envconfig.Process("", &EnvCfg); err != nil {
		log.Fatal("Failed to process env var", err)
	}
}

func WithEnvConfig() []manifest.CfgFn {
	cfg := []manifest.CfgFn{}

	if EnvCfg.RabbitmqServerImage != "" {
		cfg = append(cfg, WithRabbitmqServerImage(EnvCfg.RabbitmqServerImage))
	}

	if EnvCfg.RabbitmqImagePullSecret != "" {
		cfg = append(cfg, WithRabbitmqImagePullSecret(EnvCfg.RabbitmqImagePullSecret))
	}

	return cfg
}

func WithRabbitmqServerImage(name string) manifest.CfgFn {
	return func(cfg map[string]interface{}) {
		cfg["rabbitmqServerImage"] = name
	}
}

func WithRabbitmqImagePullSecret(name string) manifest.CfgFn {
	return func(cfg map[string]interface{}) {
		cfg["rabbitmqImagePullSecretName"] = name
	}
}

func GVR() schema.GroupVersionResource {
	return schema.GroupVersionResource{Group: "rabbitmq.com", Version: "v1beta1", Resource: "rabbitmqclusters"}
}

// Install will create a RabbitmqCluster resource, augmented with the config fn options.
func Install(name string, opts ...manifest.CfgFn) feature.StepFn {
	cfg := map[string]interface{}{
		"name": name,
	}
	for _, fn := range opts {
		fn(cfg)
	}

	return func(ctx context.Context, t feature.T) {
		if _, err := manifest.InstallYamlFS(ctx, yamls, cfg); err != nil {
			t.Fatal(err)
		}
	}
}

// IsReady tests to see if a RabbitmqCluster becomes ready within the time given.
func IsReady(name string, timing ...time.Duration) feature.StepFn {
	return k8s.IsReady(GVR(), name, timing...)
}
