defmodule Ankole.W3.ActionReceiptTest do
  @moduledoc """
  Tests for the action receipt's intent fingerprint column.

  The fingerprint is derived by the assurance chain and sealed into its
  context, so a receipt this system writes always carries one. These cases
  cover the value's requiredness and its stored shape, and the one thing a
  migration must not do: rewrite history.
  """

  use Ankole.DataCase, async: true

  alias Ankole.Company
  alias Ankole.Repo
  alias Ankole.W3.ActionReceipt

  import Ankole.PrincipalsFixtures

  @fingerprint "v1:" <> String.duplicate("a", 64)

  defp company_fixture(owner_uid) do
    suffix = System.unique_integer([:positive])

    {:ok, company} =
      %Company{}
      |> Company.changeset(%{
        uid: "w3-receipt-company-#{suffix}",
        name: "w3-receipt-company-#{suffix}",
        display_name: "W3 Receipt Test Company",
        status: :active,
        metadata: %{},
        owner_principal_uid: owner_uid
      })
      |> Repo.insert()

    company
  end

  defp receipt_attrs(company, principal, overrides \\ %{}) do
    Map.merge(
      %{
        receipt_uid: "w3-receipt-#{System.unique_integer([:positive])}",
        intent_action: "list_company_tasks",
        intent_resource: "workspace:default",
        principal_uid: principal.uid,
        company_uid: company.uid,
        risk_class: "ROUTINE",
        authz_decision: "ALLOW",
        params_hash: @fingerprint
      },
      overrides
    )
  end

  describe "params_hash requiredness" do
    test "a changeset without a fingerprint is refused" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      changeset =
        ActionReceipt.changeset(
          %ActionReceipt{},
          Map.delete(receipt_attrs(company, owner), :params_hash)
        )

      refute changeset.valid?
      assert %{params_hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "an explicit nil fingerprint is refused" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      changeset =
        ActionReceipt.changeset(
          %ActionReceipt{},
          receipt_attrs(company, owner, %{params_hash: nil})
        )

      refute changeset.valid?
      assert %{params_hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "a valid fingerprint persists and reads back unchanged" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)
      attrs = receipt_attrs(company, owner)

      assert {:ok, receipt} = ActionReceipt.changeset(%ActionReceipt{}, attrs) |> Repo.insert()
      assert receipt.params_hash == @fingerprint

      assert {:ok, loaded} = Repo.get(ActionReceipt, receipt.id) |> then(&{:ok, &1})
      assert loaded.params_hash == @fingerprint
    end

    test "the database refuses a fingerprint the application layer would never build" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      changeset =
        ActionReceipt.changeset(
          %ActionReceipt{},
          receipt_attrs(company, owner, %{params_hash: "not-a-fingerprint"})
        )

      # The application accepts the string; only the stored format is refused,
      # so the CHECK is proven here rather than assumed.
      assert changeset.valid?
      assert {:error, failed} = Repo.insert(changeset)
      assert %{params_hash: [_message]} = errors_on(failed)
    end
  end

  describe "stored fingerprint shape" do
    setup do
      %{principal: owner} = human_fixture()
      %{company: company_fixture(owner.uid), principal: owner}
    end

    test "the column accepts only a versioned lowercase sha-256", %{
      company: company,
      principal: principal
    } do
      rejected = [
        String.upcase(@fingerprint),
        "v1:" <> String.duplicate("A", 64),
        "1:" <> String.duplicate("a", 64),
        "v0:" <> String.duplicate("a", 64),
        "v01:" <> String.duplicate("a", 64),
        "v1:" <> String.duplicate("a", 63),
        "v1:" <> String.duplicate("a", 65),
        "v1:" <> String.duplicate("g", 64),
        "v1:" <> String.duplicate("a", 64) <> "\n",
        "v1:" <> String.duplicate("a", 64) <> " ",
        "sha256:" <> String.duplicate("a", 64),
        String.duplicate("a", 64)
      ]

      for value <- rejected do
        changeset =
          ActionReceipt.changeset(
            %ActionReceipt{},
            receipt_attrs(company, principal, %{params_hash: value})
          )

        assert {:error, failed} = Repo.insert(changeset),
               "#{inspect(value)} was accepted by the stored format"

        assert %{params_hash: [_message]} = errors_on(failed)
      end
    end

    test "the column accepts a later schema version and a current one", %{
      company: company,
      principal: principal
    } do
      for value <- [
            "v1:" <> String.duplicate("a", 64),
            "v2:" <> String.duplicate("b", 64),
            "v10:" <> String.duplicate("c", 64)
          ] do
        changeset =
          ActionReceipt.changeset(
            %ActionReceipt{},
            receipt_attrs(company, principal, %{params_hash: value})
          )

        assert {:ok, receipt} = Repo.insert(changeset),
               "#{inspect(value)} was refused by the stored format"

        assert receipt.params_hash == value
      end
    end

    test "a NULL fingerprint is still storable, so a historical row survives", %{
      company: company,
      principal: principal
    } do
      Repo.query!(
        """
        INSERT INTO action_receipts
          (id, receipt_uid, intent_action, intent_resource, principal_uid, company_uid,
           risk_class, authz_decision, params_hash, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULL, now(), now())
        RETURNING id
        """,
        [
          Ecto.UUID.dump!(Ecto.UUID.generate()),
          "w3-receipt-historical-#{System.unique_integer([:positive])}",
          "list_company_tasks",
          "workspace:default",
          principal.uid,
          company.uid,
          "ROUTINE",
          "ALLOW"
        ]
      )

      historical =
        Repo.all(from(r in ActionReceipt, where: like(r.receipt_uid, "w3-receipt-historical-%")))

      assert length(historical) == 1
      assert is_nil(hd(historical).params_hash)
    end
  end

  describe "receipt fidelity" do
    test "a receipt written by the system records the derived fingerprint" do
      %{principal: owner} = human_fixture()
      company = company_fixture(owner.uid)

      attrs = receipt_attrs(company, owner)

      assert {:ok, receipt} = ActionReceipt.changeset(%ActionReceipt{}, attrs) |> Repo.insert()

      # The other unevaluated columns stay honest about not having run.
      assert is_nil(receipt.precondition_status)
      assert is_nil(receipt.approval_independent)
      assert is_nil(receipt.execution_failed)
      assert receipt.params_hash == @fingerprint
    end

    test "the fingerprint is not indexed, so a query plan cannot depend on it" do
      %{rows: rows} =
        Repo.query!("""
        SELECT indexdef
        FROM pg_indexes
        WHERE tablename = 'action_receipts'
          AND indexdef LIKE '%(params_hash)%'
        """)

      assert rows == []
    end

    test "the stored format is declared as a named database constraint" do
      %{rows: rows} =
        Repo.query!("""
        SELECT conname, pg_get_constraintdef(oid)
        FROM pg_constraint
        WHERE conrelid = 'action_receipts'::regclass
          AND conname = 'action_receipts_params_hash_format'
        """)

      assert [[name, definition]] = rows
      assert name == "action_receipts_params_hash_format"
      assert definition =~ "params_hash"
      assert definition =~ "CHECK"
    end
  end
end
