SHELL ?= /bin/bash

# current dir
ROOT_DIR := $(shell pwd)
OUTPUT_DIR := ${ROOT_DIR}/_output
TOOLS_DIR := ${OUTPUT_DIR}/tools


ifndef $(GOPATH)
	GOPATH=$(shell go env GOPATH)
	export GOPATH
endif

K8S_CODE_GEN_DIR := ./vendor/k8s.io/code-generator



.PHONY: gen
gen: gen.k8s.external gen.k8s.internal gen.pb

gen.k8s.external:
	@go mod vendor
	@chmod +x  ${K8S_CODE_GEN_DIR}/*.sh
	@${K8S_CODE_GEN_DIR}/generate-groups.sh all \
		k8s.io/sample-apiserver/pkg/generated \
  		k8s.io/sample-apiserver/pkg/apis \
  		"wardle:v1alpha1,v1beta1" \
        --output-base ./../.. \
        --go-header-file ./hack/boilerplate.go.txt

gen.k8s.internal:
	@chmod +x  ${K8S_CODE_GEN_DIR}/*.sh
	@${K8S_CODE_GEN_DIR}/generate-internal-groups.sh "deepcopy,defaulter,conversion,openapi" \
	    k8s.io/sample-apiserver/pkg/generated \
	    k8s.io/sample-apiserver/pkg/apis \
	    k8s.io/sample-apiserver/pkg/apis \
	    "wardle:v1alpha1,v1beta1" \
	    --go-header-file=./hack/boilerplate.go.txt \
        --output-base ./../.. \
        -v 10


gen.pb:
	GOBIN=${TOOLS_DIR} go install k8s.io/code-generator/cmd/go-to-protobuf@latest
	${TOOLS_DIR}/go-to-protobuf \
		--go-header-file=./hack/boilerplate.go.txt \
		--packages=k8s.io/sample-apiserver/pkg/apis/wardle/v1alpha1,k8s.io/sample-apiserver/pkg/apis/wardle/v1beta1 \
		--apimachinery-packages=-k8s.io/apimachinery/pkg/runtime/schema,-k8s.io/apimachinery/pkg/runtime,-k8s.io/apimachinery/pkg/apis/meta/v1  \
		--proto-import ./vendor \
		-o ./../../..

.PHONY: clean
clean:
	@-rm -rf $(OUTPUT_DIR)
	@-rm -rf vendor
	@-rm -rf ./pkg/generated
	@find ./pkg -regex '.*/.*generated.*'  -type f -exec rm -rf {} \;
	@-find . -regex './.*\.json' -type f -exec rm -rf {} \;
	@-find . -regex './.*\.pem' -type f -exec rm -rf {} \;
	@-find . -regex './.*\.csr' -type f -exec rm -rf {} \;
	@-find . -regextype egrep  -regex './.*\.(json|pem|csr)$' -type f -exec rm -rf {} \;



.PHONY: tools
tools: tools.cfssl

tools.cfssl:
	# install to tool_dir
	@GOBIN=$(TOOLS_DIR) go install github.com/google/go-jsonnet/cmd/...@latest
	@GOBIN=$(TOOLS_DIR) go install github.com/cloudflare/cfssl/cmd/...@latest

.PHONY: gen.config
gen.config: tools
	# generate cfssl config
	@$(TOOLS_DIR)/jsonnet ./hack/config.jsonnet -o config.json

.PHONY: gen.csr
gen.csr: gen.config
	@$(TOOLS_DIR)/jsonnet --ext-code params='{is_ca:true, common_name:"ca.vulcanus.io", hosts: ["ca.vulcanus.io"]}' ./hack/csr.jsonnet -o ca-csr.json
	@$(TOOLS_DIR)/jsonnet --ext-code params='{is_ca:false, common_name:"svr.vulcanus.io", hosts: ["svr.vulcanus.io"]}' ./hack/csr.jsonnet -o svr-csr.json

.PHONY: gen.certs
gen.certs: gen.csr
	@$(TOOLS_DIR)/cfssl gencert -config=config.json -initca ca-csr.json | $(TOOLS_DIR)/cfssljson -bare ca
	@$(TOOLS_DIR)/cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=config.json -profile=server svr-csr.json | $(TOOLS_DIR)/cfssljson -bare svr
	@base64 -i ca.pem # show ca base64


.PHONE: create.secret
create.secret:
	@kubectl delete secret protector-certs  -n test
	@kubectl create secret tls protector-certs --cert=protector.pem --key=protector-key.pem -n test