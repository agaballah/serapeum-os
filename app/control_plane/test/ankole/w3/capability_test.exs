defmodule Ankole.W3.CapabilityTest do
  @moduledoc """
  Schema-level tests for the P2 Capability model.

  These tests exercise the changeset contract only. They do not require a
  database and do not touch the Company boundary.
  """

  use Ankole.DataCase, async: true

  alias Ankole.W3.Capability

  import Ankole.PrincipalsFixtures

  describe "changeset" do
    test "valid attrs produce a valid changeset" do
      owner = human_fixture()

      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-001",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          status: :active,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: owner.principal.uid,
          scope: %{"task_uid" => "task-1"},
          constraints: %{"max_duration" => 3600},
          metadata: %{"source" => "bootstrap"}
        })

      assert cs.valid?
      assert get_field(cs, :status) == :active
      assert get_field(cs, :risk_class) == "ROUTINE"
      assert get_field(cs, :scope) == %{"task_uid" => "task-1"}
      assert get_field(cs, :constraints) == %{"max_duration" => 3600}
      assert get_field(cs, :metadata) == %{"source" => "bootstrap"}
    end

    test "default status is :active" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-002",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "CONTROLLED",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :active
    end

    test "default scope, constraints, and metadata are empty maps" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-003",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      assert cs.valid?
      assert get_field(cs, :scope) == %{}
      assert get_field(cs, :constraints) == %{}
      assert get_field(cs, :metadata) == %{}
    end

    test "rejects missing required fields" do
      cs = Capability.changeset(%Capability{}, %{})

      refute cs.valid?
      assert cs.errors[:uid]
      assert cs.errors[:company_uid]
      assert cs.errors[:principal_uid]
      assert cs.errors[:action]
      assert cs.errors[:resource]
      assert cs.errors[:risk_class]
      assert cs.errors[:issued_at]
      assert cs.errors[:issued_by_principal_uid]
    end

    test "rejects blank action after trim" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-004",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "   ",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:action]
    end

    test "rejects blank resource after trim" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-005",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:resource]
    end

    test "rejects blank uid after trim" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:uid]
    end

    test "rejects blank risk_class after trim" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-006",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "  ",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:risk_class]
    end

    test "lowercases action during normalization" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-007",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "WORKSPACE:READ",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      assert cs.valid?
      assert get_field(cs, :action) == "workspace:read"
    end

    test "rejects invalid status value" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-008",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          status: :pending,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:status]
    end

    test "revoked status is valid" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-009",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          status: :revoked,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :revoked
    end

    test "expired status is valid" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-010",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          status: :expired,
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      assert cs.valid?
      assert get_field(cs, :status) == :expired
    end

    test "rejects missing issued_at" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-011",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:issued_at]
    end

    test "accepts all four canonical risk classes" do
      for class <- ["ROUTINE", "CONTROLLED", "HIGH-IMPACT", "PROHIBITED"] do
        cs =
          Capability.changeset(%Capability{}, %{
            uid: "cap-#{class}-001",
            company_uid: "company-a",
            principal_uid: "principal-a",
            action: "workspace:read",
            resource: "workspace:default",
            risk_class: class,
            issued_at: ~U[2026-09-26 10:00:00Z],
            issued_by_principal_uid: "issuer-1"
          })

        assert cs.valid?, "expected #{class} to be valid"
      end
    end

    test "rejects invalid risk class value" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-012",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "UNKNOWN",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1"
        })

      refute cs.valid?
      assert cs.errors[:risk_class]
    end

    test "nullable fields accept nil without error" do
      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-013",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1",
          expires_at: nil,
          revoked_at: nil,
          parent_capability_uid: nil,
          approval_uid: nil
        })

      assert cs.valid?
      assert is_nil(get_field(cs, :expires_at))
      assert is_nil(get_field(cs, :revoked_at))
      assert is_nil(get_field(cs, :parent_capability_uid))
      assert is_nil(get_field(cs, :approval_uid))
    end

    test "accepts non-nil expires_at and revoked_at" do
      expires = ~U[2026-10-26 10:00:00Z]
      revoked = ~U[2026-09-27 10:00:00Z]

      cs =
        Capability.changeset(%Capability{}, %{
          uid: "cap-014",
          company_uid: "company-a",
          principal_uid: "principal-a",
          action: "workspace:read",
          resource: "workspace:default",
          risk_class: "ROUTINE",
          issued_at: ~U[2026-09-26 10:00:00Z],
          issued_by_principal_uid: "issuer-1",
          expires_at: expires,
          revoked_at: revoked,
          parent_capability_uid: "parent-cap-uid",
          approval_uid: "approval-uid"
        })

      assert cs.valid?
      assert get_field(cs, :expires_at) >= expires
      assert get_field(cs, :revoked_at) >= revoked
      assert get_field(cs, :parent_capability_uid) == "parent-cap-uid"
      assert get_field(cs, :approval_uid) == "approval-uid"
    end
  end

  describe "canonical_statuses/0" do
    test "returns the three P2 statuses" do
      assert Capability.canonical_statuses() == [:active, :revoked, :expired]
    end
  end

  describe "canonical_risk_classes/0" do
    test "returns the four architectural risk classes" do
      assert Capability.canonical_risk_classes() == ~w(ROUTINE CONTROLLED HIGH-IMPACT PROHIBITED)
    end
  end
end