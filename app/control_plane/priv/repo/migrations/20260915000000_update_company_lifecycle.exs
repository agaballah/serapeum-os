defmodule Ankole.Repo.Migrations.UpdateCompanyLifecycle do
  @moduledoc false

  use Ecto.Migration

  def up do
    drop constraint(:companies, :companies_status_valid)
    create constraint(
           :companies,
           :companies_status_valid,
           check: "status IN ('created', 'active', 'suspended', 'archived')"
         )
  end

  def down do
    drop constraint(:companies, :companies_status_valid)
    create constraint(
           :companies,
           :companies_status_valid,
           check: "status IN ('active', 'disabled')"
         )
  end
end
