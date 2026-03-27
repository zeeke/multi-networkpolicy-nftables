#!/usr/bin/env bats

# Reproducer for: "Stacked policies enforce multiple Ingress stacked policies
# with overlapping podSelector and different ports"
#
# Test Setup:
# - 3 namespaces: nsX, nsY, nsZ
# - nsX has pod-a (server on 5555+6666), pod-b, pod-c
# - nsY and nsZ have pod-b and pod-c
# - Policy 1 (in nsX): allow ingress from pod=b on port 5555
# - Policy 2 (in nsX): allow ingress from pod=c on port 6666
#
# Expected (podSelector without namespaceSelector matches policy namespace only):
# - nsX/pod-b -> pod-a:5555 ALLOWED, pod-a:6666 BLOCKED
# - nsX/pod-c -> pod-a:6666 ALLOWED, pod-a:5555 BLOCKED
# - nsY,nsZ pods -> pod-a (any port) BLOCKED (wrong namespace)

setup() {
	cd $BATS_TEST_DIRNAME
	load "common"

	server_net1=$(get_net1_ip "test-stacked-ports-x" "pod-a")
}

@test "setup stacked-ports test environments" {
	kubectl create -f stacked-ports.yml

	run kubectl -n test-stacked-ports-x wait --for=condition=ready -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	run kubectl -n test-stacked-ports-y wait --for=condition=ready -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	run kubectl -n test-stacked-ports-z wait --for=condition=ready -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]

	sleep 10
}

@test "check generated nftables rules" {
	sleep 10

	# Only pod-a in nsX should have nftables rules (policy target)
	run has_nftables_table "test-stacked-ports-x" "pod-a"
	[ "$status" -eq  "0" ]

	run has_nftables_table "test-stacked-ports-x" "pod-b"
	[ "$status" -eq  "1" ]

	run has_nftables_table "test-stacked-ports-x" "pod-c"
	[ "$status" -eq  "1" ]
}

# Same-namespace tests (nsX)
@test "stacked-ports check nsX/pod-b -> pod-a:5555 (allowed by policy 1)" {
	run kubectl -n test-stacked-ports-x exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "0" ]
}

@test "stacked-ports check nsX/pod-b -> pod-a:6666 (blocked, wrong port)" {
	run kubectl -n test-stacked-ports-x exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsX/pod-c -> pod-a:6666 (allowed by policy 2)" {
	run kubectl -n test-stacked-ports-x exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "0" ]
}

@test "stacked-ports check nsX/pod-c -> pod-a:5555 (blocked, wrong port)" {
	run kubectl -n test-stacked-ports-x exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

# Cross-namespace tests (nsY) - all blocked because podSelector without
# namespaceSelector only matches pods in the policy's namespace (nsX)
@test "stacked-ports check nsY/pod-b -> pod-a:5555 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-y exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsY/pod-b -> pod-a:6666 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-y exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsY/pod-c -> pod-a:6666 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-y exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsY/pod-c -> pod-a:5555 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-y exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

# Cross-namespace tests (nsZ) - all blocked for same reason
@test "stacked-ports check nsZ/pod-b -> pod-a:5555 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-z exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsZ/pod-b -> pod-a:6666 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-z exec pod-b -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsZ/pod-c -> pod-a:6666 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-z exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 6666"
	[ "$status" -eq  "1" ]
}

@test "stacked-ports check nsZ/pod-c -> pod-a:5555 (blocked, cross-ns)" {
	run kubectl -n test-stacked-ports-z exec pod-c -- sh -c "echo x | nc -w 1 ${server_net1} 5555"
	[ "$status" -eq  "1" ]
}

@test "cleanup environments" {
	kubectl delete -f stacked-ports.yml
	run kubectl -n test-stacked-ports-x wait --for=delete -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
	run kubectl -n test-stacked-ports-y wait --for=delete -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
	run kubectl -n test-stacked-ports-z wait --for=delete -l app=test-stacked-ports pod --timeout=${kubewait_timeout}
	[ "$status" -eq  "0" ]
}
