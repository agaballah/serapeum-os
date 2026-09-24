defmodule Ankole.WorkHierarchy.ReviewEventTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.ReviewEvent

  @moduledoc """
  Tests for Ankole.WorkHierarchy.ReviewEvent schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "created",
        reviewer_uid: "human-001"
      })

      assert changeset.valid?
    end

    test "review_uid is required" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        event_type: "created"
      })

      assert Enum.any?(changeset.errors, fn {:review_uid, _} -> true; _ -> false end)
    end

    test "event_type is required" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001"
      })

      assert Enum.any?(changeset.errors, fn {:event_type, _} -> true; _ -> false end)
    end

    test "created event_type is accepted" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "created"
      })

      assert changeset.valid?
    end

    test "invalidated event_type is accepted" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "invalidated"
      })

      assert changeset.valid?
    end

    test "unknown event_type is rejected" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "unknown"
      })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {:event_type, _} -> true; _ -> false end)
    end

    test "reviewer_uid accepts PrincipalKey" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "created",
        reviewer_uid: "human-001"
      })

      assert changeset.valid?
    end

    test "metadata accepts jsonb" do
      changeset = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "review-001",
        event_type: "created",
        reviewer_uid: "human-001",
        metadata: %{"reason" => "superseded"}
      })

      assert changeset.valid?
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = ReviewEvent.__schema__(:fields)
      assert :id in fields
      assert :review_uid in fields
      assert :event_type in fields
      assert :reviewer_uid in fields
      assert :metadata in fields
      assert :inserted_at in fields
    end

    test "primary key is id" do
      assert ReviewEvent.__schema__(:primary_key) == [:id]
    end
  end

  describe "constraint wiring" do
    test "FK constraint on review_uid is wired" do
      constraints = ReviewEvent.changeset(%ReviewEvent{}, %{
        review_uid: "r1", event_type: "created"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :review_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "review_uid is stored as :string" do
      assert ReviewEvent.__schema__(:type, :review_uid) == :string
    end

    test "event_type is stored as :string" do
      assert ReviewEvent.__schema__(:type, :event_type) == :string
    end

    test "reviewer_uid is stored as Ankole.Ecto.PrincipalKey" do
      assert ReviewEvent.__schema__(:type, :reviewer_uid) == Ankole.Ecto.PrincipalKey
    end

    test "metadata is stored as :map" do
      assert ReviewEvent.__schema__(:type, :metadata) == :map
    end
  end
end
