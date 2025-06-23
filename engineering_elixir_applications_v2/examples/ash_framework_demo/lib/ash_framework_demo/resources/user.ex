defmodule AshFrameworkDemo.Resources.User do
  @moduledoc """
  Advanced Ash Framework User Resource demonstrating v2 patterns:
  - Authentication integration
  - Authorization policies
  - Aggregates and calculations
  - Real-time subscriptions
  - Audit trails with Archival
  """
  
  use Ash.Resource,
    domain: AshFrameworkDemo.Core,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshAuthentication,
      AshArchival.Resource,
      AshStateMachine,
      AshAdmin.Resource
    ]

  postgres do
    table "users"
    repo AshFrameworkDemo.Repo

    references do
      reference :organization, on_delete: :delete, on_update: :update
    end
  end

  authentication do
    api AshFrameworkDemo.Core

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        register_action_accept [:email, :first_name, :last_name, :organization_id]
      end

      oauth2 :github do
        client_id System.get_env("GITHUB_CLIENT_ID")
        client_secret System.get_env("GITHUB_CLIENT_SECRET")
        redirect_uri System.get_env("GITHUB_REDIRECT_URI")
      end
    end

    tokens do
      enabled? true
      token_resource AshFrameworkDemo.Resources.UserToken
      signing_secret System.get_env("AUTH_SECRET")
    end
  end

  state_machine do
    initial_states [:pending]
    default_initial_state :pending

    transitions do
      transition :activate, from: :pending, to: :active
      transition :deactivate, from: :active, to: :inactive
      transition :suspend, from: [:active, :inactive], to: :suspended
      transition :reactivate, from: :suspended, to: :active
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :active, :inactive, :suspended]
      default :pending
      public? true
    end

    attribute :last_signed_in_at, :utc_datetime_usec do
      public? true
    end

    attribute :sign_in_count, :integer do
      default 0
      public? true
    end

    attribute :preferences, :map do
      default %{}
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, AshFrameworkDemo.Resources.Organization do
      allow_nil? true
      public? true
    end

    has_many :posts, AshFrameworkDemo.Resources.Post do
      public? true
    end

    has_many :comments, AshFrameworkDemo.Resources.Comment do
      public? true
    end

    many_to_many :roles, AshFrameworkDemo.Resources.Role do
      through AshFrameworkDemo.Resources.UserRole
      public? true
    end
  end

  aggregates do
    count :posts_count, :posts
    count :comments_count, :comments
    
    first :latest_post, :posts, :inserted_at do
      sort inserted_at: :desc
    end

    sum :total_post_views, :posts, :view_count
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name) do
      public? true
    end

    calculate :is_active, :boolean, expr(status == :active) do
      public? true
    end

    calculate :activity_score, :integer do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          base_score = record.posts_count * 10 + record.comments_count * 2
          recency_bonus = if record.last_signed_in_at && 
                            DateTime.diff(DateTime.utc_now(), record.last_signed_in_at, :day) < 7,
                            do: 50, else: 0
          base_score + recency_bonus
        end)
      end
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if actor_attribute_equals(:id, :id)
      authorize_if relates_to_actor_via(:organization)
      authorize_if actor_has_role([:admin, :moderator])
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:id, :id)
      authorize_if actor_has_role([:admin])
    end

    policy action_type(:destroy) do
      authorize_if actor_has_role([:admin])
    end
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      accept [:email, :first_name, :last_name, :organization_id]
      
      change hash_password(:password)
      change set_attribute(:status, :pending)
    end

    update :activate do
      accept []
      
      change transition_state(:active)
      change set_attribute(:last_signed_in_at, &DateTime.utc_now/0)
      change increment(:sign_in_count)
    end

    update :sign_in do
      accept []
      
      change set_attribute(:last_signed_in_at, &DateTime.utc_now/0)
      change increment(:sign_in_count)
    end

    update :update_preferences do
      accept [:preferences]
      
      validate present(:preferences)
    end

    action :send_welcome_email, :map do
      run AshFrameworkDemo.Actions.SendWelcomeEmail
    end

    read :by_organization do
      argument :organization_id, :uuid do
        allow_nil? false
      end

      filter expr(organization_id == ^arg(:organization_id))
    end

    read :active_users do
      filter expr(status == :active)
    end

    read :search do
      argument :query, :string do
        allow_nil? false
      end

      filter expr(
        ilike(first_name, ^arg(:query)) or
        ilike(last_name, ^arg(:query)) or
        ilike(email, ^arg(:query))
      )
    end
  end

  validations do
    validate match(:email, ~r/.+@.+\..+/), message: "must be a valid email address"
    validate string_length(:first_name, min: 1, max: 100)
    validate string_length(:last_name, min: 1, max: 100)
  end

  changes do
    change before_action(fn changeset, _context ->
      case changeset.action.name do
        :create ->
          # Generate welcome email job
          changeset
          |> Ash.Changeset.after_action(fn _changeset, user ->
            AshFrameworkDemo.Jobs.WelcomeEmailJob.new(%{user_id: user.id})
            |> Oban.insert()
            
            {:ok, user}
          end)
        _ ->
          changeset
      end
    end)
  end

  admin do
    table_columns [
      :id,
      :email,
      :full_name,
      :status,
      :organization,
      :posts_count,
      :last_signed_in_at,
      :inserted_at
    ]

    format_fields [
      last_signed_in_at: {AshAdmin.Components.Resource.Table, :format_datetime, []},
      inserted_at: {AshAdmin.Components.Resource.Table, :format_datetime, []}
    ]
  end

  json_api do
    type "user"
    
    routes do
      base "/users"
      
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
      
      get :by_organization, route: "/organization/:organization_id"
      get :active_users, route: "/active"
      get :search, route: "/search"
    end
  end

  graphql do
    type :user

    queries do
      get :user, :read
      list :users, :read
      list :active_users, :active_users
      list :search_users, :search
    end

    mutations do
      create :create_user, :create
      update :update_user, :update
      update :activate_user, :activate
      destroy :delete_user, :destroy
    end

    subscriptions do
      subscribe :user_updated, :update
      subscribe :user_created, :create
    end
  end
end