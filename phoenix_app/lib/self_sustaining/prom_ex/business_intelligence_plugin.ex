defmodule SelfSustaining.PromEx.BusinessIntelligencePlugin do
  @moduledoc """
  PromEx Plugin for Business Intelligence and Value Tracking

  Specialized PromEx plugin that provides comprehensive business metrics for the
  AI Self-Sustaining System, tracking business value delivery, feature adoption,
  user satisfaction, and system ROI.

  This plugin follows Engineering Elixir Applications patterns and provides
  metrics that enable data-driven business decisions and system optimization.

  ## Metrics Provided

  ### Business Value Tracking
  - `self_sustaining_business_value_delivered_total` - Quantified business value by type
  - `self_sustaining_feature_adoption_ratio` - Feature adoption and usage rates
  - `self_sustaining_user_satisfaction_score` - User experience metrics
  - `self_sustaining_system_roi_ratio` - Return on investment calculation

  ### System Performance Intelligence
  - `self_sustaining_system_reliability_score` - Overall system reliability
  - `self_sustaining_performance_score` - System performance metrics
  - `self_sustaining_availability_ratio` - System availability tracking
  - `self_sustaining_error_budget_consumption` - Error budget utilization

  ### Operational Intelligence
  - `self_sustaining_operational_efficiency_ratio` - Operational efficiency
  - `self_sustaining_cost_per_operation` - Cost effectiveness metrics
  - `self_sustaining_automation_ratio` - Automation coverage
  - `self_sustaining_manual_intervention_count` - Manual intervention tracking

  ### User Experience Intelligence
  - `self_sustaining_user_journey_completion_ratio` - User journey success
  - `self_sustaining_response_quality_score` - Response quality metrics
  - `self_sustaining_user_engagement_score` - User engagement tracking
  - `self_sustaining_feedback_sentiment_score` - User feedback analysis

  ## Integration

  This plugin integrates with:
  - Business process telemetry
  - User interaction tracking
  - System performance metrics
  - Financial and operational data
  """

  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :self_sustaining_business_intelligence_event_metrics,
      [
        # Business Value Tracking
        counter(
          "self_sustaining_business_value_delivered_total",
          event_name: [:self_sustaining, :business, :value, :delivered],
          description: "Total business value delivered by type and source",
          measurement: :value_amount,
          tags: [:value_type, :source, :category, :team],
          tag_values: &get_business_value_tags/1
        ),
        last_value(
          "self_sustaining_feature_adoption_ratio",
          event_name: [:self_sustaining, :feature, :adoption, :measured],
          description: "Feature adoption ratio (0-1) by feature and user segment",
          measurement: :adoption_ratio,
          tags: [:feature_name, :user_segment, :adoption_type],
          tag_values: &get_feature_adoption_tags/1
        ),
        last_value(
          "self_sustaining_user_satisfaction_score",
          event_name: [:self_sustaining, :user, :satisfaction, :measured],
          description: "User satisfaction score (0-100) by interaction type",
          measurement: :satisfaction_score,
          tags: [:interaction_type, :user_segment, :feature_area],
          tag_values: &get_user_satisfaction_tags/1
        ),
        last_value(
          "self_sustaining_system_roi_ratio",
          event_name: [:self_sustaining, :system, :roi, :calculated],
          description: "System return on investment ratio",
          measurement: :roi_ratio,
          tags: [:calculation_period, :cost_category, :benefit_type],
          tag_values: &get_system_roi_tags/1
        ),

        # System Performance Intelligence
        last_value(
          "self_sustaining_system_reliability_score",
          event_name: [:self_sustaining, :system, :reliability, :measured],
          description: "Overall system reliability score (0-100)",
          measurement: :reliability_score,
          tags: [:component, :measurement_type],
          tag_values: &get_system_reliability_tags/1
        ),
        last_value(
          "self_sustaining_performance_score",
          event_name: [:self_sustaining, :system, :performance, :measured],
          description: "System performance score (0-100) by component",
          measurement: :performance_score,
          tags: [:component, :metric_type, :time_period],
          tag_values: &get_performance_score_tags/1
        ),
        last_value(
          "self_sustaining_availability_ratio",
          event_name: [:self_sustaining, :system, :availability, :measured],
          description: "System availability ratio (0-1) by service",
          measurement: :availability_ratio,
          tags: [:service_name, :measurement_period],
          tag_values: &get_availability_tags/1
        ),
        last_value(
          "self_sustaining_error_budget_consumption",
          event_name: [:self_sustaining, :system, :error_budget, :measured],
          description: "Error budget consumption ratio (0-1)",
          measurement: :consumption_ratio,
          tags: [:service_name, :slo_type, :time_window],
          tag_values: &get_error_budget_tags/1
        ),

        # Operational Intelligence
        last_value(
          "self_sustaining_operational_efficiency_ratio",
          event_name: [:self_sustaining, :operations, :efficiency, :measured],
          description: "Operational efficiency ratio (0-1) by operation type",
          measurement: :efficiency_ratio,
          tags: [:operation_type, :team, :automation_level],
          tag_values: &get_operational_efficiency_tags/1
        ),
        last_value(
          "self_sustaining_cost_per_operation",
          event_name: [:self_sustaining, :operations, :cost, :calculated],
          description: "Cost per operation in dollars",
          measurement: :cost_dollars,
          tags: [:operation_type, :cost_category, :resource_type],
          tag_values: &get_cost_per_operation_tags/1
        ),
        last_value(
          "self_sustaining_automation_ratio",
          event_name: [:self_sustaining, :automation, :coverage, :measured],
          description: "Automation coverage ratio (0-1) by process area",
          measurement: :automation_ratio,
          tags: [:process_area, :automation_type, :maturity_level],
          tag_values: &get_automation_ratio_tags/1
        ),
        counter(
          "self_sustaining_manual_intervention_count",
          event_name: [:self_sustaining, :manual, :intervention, :required],
          description: "Manual intervention count by reason and urgency",
          tags: [:intervention_reason, :urgency_level, :component],
          tag_values: &get_manual_intervention_tags/1
        ),

        # User Experience Intelligence
        last_value(
          "self_sustaining_user_journey_completion_ratio",
          event_name: [:self_sustaining, :user_journey, :completion, :measured],
          description: "User journey completion ratio (0-1) by journey type",
          measurement: :completion_ratio,
          tags: [:journey_type, :user_segment, :entry_point],
          tag_values: &get_user_journey_tags/1
        ),
        last_value(
          "self_sustaining_response_quality_score",
          event_name: [:self_sustaining, :response, :quality, :measured],
          description: "Response quality score (0-100) by interaction type",
          measurement: :quality_score,
          tags: [:interaction_type, :response_type, :ai_model],
          tag_values: &get_response_quality_tags/1
        ),
        last_value(
          "self_sustaining_user_engagement_score",
          event_name: [:self_sustaining, :user, :engagement, :measured],
          description: "User engagement score (0-100) by feature area",
          measurement: :engagement_score,
          tags: [:feature_area, :user_segment, :session_type],
          tag_values: &get_user_engagement_tags/1
        ),
        last_value(
          "self_sustaining_feedback_sentiment_score",
          event_name: [:self_sustaining, :feedback, :sentiment, :analyzed],
          description: "Feedback sentiment score (-1 to 1) by feedback type",
          measurement: :sentiment_score,
          tags: [:feedback_type, :feedback_source, :topic_category],
          tag_values: &get_feedback_sentiment_tags/1
        ),

        # Financial Intelligence
        counter(
          "self_sustaining_revenue_generated_total",
          event_name: [:self_sustaining, :revenue, :generated],
          description: "Total revenue generated in dollars by source",
          measurement: :revenue_dollars,
          tags: [:revenue_source, :customer_segment, :product_area],
          tag_values: &get_revenue_tags/1
        ),
        counter(
          "self_sustaining_cost_savings_total",
          event_name: [:self_sustaining, :cost_savings, :realized],
          description: "Total cost savings in dollars by optimization type",
          measurement: :savings_dollars,
          tags: [:optimization_type, :cost_category, :savings_source],
          tag_values: &get_cost_savings_tags/1
        )
      ]
    )
  end

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 30_000)

    Polling.build(
      :self_sustaining_business_intelligence_polling_metrics,
      poll_rate,
      {__MODULE__, :execute_business_intelligence_polling, []},
      [
        # Business KPI Polling
        last_value(
          "self_sustaining_monthly_active_users",
          event_name: [:self_sustaining, :users, :active, :monthly],
          description: "Monthly active users count",
          measurement: :user_count,
          tags: [:user_type, :engagement_level],
          tag_values: &get_monthly_users_tags/1
        ),
        last_value(
          "self_sustaining_customer_lifetime_value",
          event_name: [:self_sustaining, :customer, :ltv, :calculated],
          description: "Customer lifetime value in dollars",
          measurement: :ltv_dollars,
          tags: [:customer_segment, :acquisition_channel],
          tag_values: &get_customer_ltv_tags/1
        ),
        last_value(
          "self_sustaining_churn_rate",
          event_name: [:self_sustaining, :churn, :rate, :calculated],
          description: "Customer churn rate (0-1) by segment",
          measurement: :churn_rate,
          tags: [:customer_segment, :time_period, :churn_reason],
          tag_values: &get_churn_rate_tags/1
        )
      ]
    )
  end

  ## Polling Execution Function

  def execute_business_intelligence_polling do
    try do
      # Emit business intelligence metrics
      # For now, emit static values - in production these would come from real data sources

      # Monthly active users metric
      :telemetry.execute(
        [:self_sustaining, :users, :active, :monthly],
        # Example value
        %{user_count: 1500},
        %{user_type: "active", engagement_level: "medium"}
      )

      # Customer lifetime value metric
      :telemetry.execute(
        [:self_sustaining, :customer, :ltv, :calculated],
        # Example value
        %{ltv_dollars: 2500.0},
        %{customer_segment: "enterprise", acquisition_channel: "direct"}
      )

      # Churn rate metric
      :telemetry.execute(
        [:self_sustaining, :churn, :rate, :calculated],
        # 5% churn rate example
        %{churn_rate: 0.05},
        %{customer_segment: "enterprise", time_period: "monthly", churn_reason: "unknown"}
      )

      :ok
    rescue
      e ->
        # Log error but don't crash metrics collection
        require Logger
        Logger.warning("PromEx business intelligence polling error: #{inspect(e)}")
        :ok
    end
  end

  ## Tag Value Functions

  defp get_business_value_tags(metadata) do
    %{
      value_type: Map.get(metadata, :value_type, "unknown"),
      source: Map.get(metadata, :source, "system"),
      category: Map.get(metadata, :category, "efficiency"),
      team: Map.get(metadata, :team, "default")
    }
  end

  defp get_feature_adoption_tags(metadata) do
    %{
      feature_name: sanitize_feature_name(Map.get(metadata, :feature_name, "unknown")),
      user_segment: Map.get(metadata, :user_segment, "general"),
      adoption_type: Map.get(metadata, :adoption_type, "usage")
    }
  end

  defp get_user_satisfaction_tags(metadata) do
    %{
      interaction_type: Map.get(metadata, :interaction_type, "general"),
      user_segment: Map.get(metadata, :user_segment, "general"),
      feature_area: Map.get(metadata, :feature_area, "core")
    }
  end

  defp get_system_roi_tags(metadata) do
    %{
      calculation_period: Map.get(metadata, :calculation_period, "monthly"),
      cost_category: Map.get(metadata, :cost_category, "operational"),
      benefit_type: Map.get(metadata, :benefit_type, "efficiency")
    }
  end

  defp get_system_reliability_tags(metadata) do
    %{
      component: Map.get(metadata, :component, "system"),
      measurement_type: Map.get(metadata, :measurement_type, "overall")
    }
  end

  defp get_performance_score_tags(metadata) do
    %{
      component: Map.get(metadata, :component, "system"),
      metric_type: Map.get(metadata, :metric_type, "response_time"),
      time_period: Map.get(metadata, :time_period, "current")
    }
  end

  defp get_availability_tags(metadata) do
    %{
      service_name: Map.get(metadata, :service_name, "core"),
      measurement_period: Map.get(metadata, :measurement_period, "daily")
    }
  end

  defp get_error_budget_tags(metadata) do
    %{
      service_name: Map.get(metadata, :service_name, "core"),
      slo_type: Map.get(metadata, :slo_type, "availability"),
      time_window: Map.get(metadata, :time_window, "daily")
    }
  end

  defp get_operational_efficiency_tags(metadata) do
    %{
      operation_type: Map.get(metadata, :operation_type, "general"),
      team: Map.get(metadata, :team, "default"),
      automation_level: Map.get(metadata, :automation_level, "partial")
    }
  end

  defp get_cost_per_operation_tags(metadata) do
    %{
      operation_type: Map.get(metadata, :operation_type, "general"),
      cost_category: Map.get(metadata, :cost_category, "compute"),
      resource_type: Map.get(metadata, :resource_type, "cpu")
    }
  end

  defp get_automation_ratio_tags(metadata) do
    %{
      process_area: Map.get(metadata, :process_area, "general"),
      automation_type: Map.get(metadata, :automation_type, "workflow"),
      maturity_level: Map.get(metadata, :maturity_level, "intermediate")
    }
  end

  defp get_manual_intervention_tags(metadata) do
    %{
      intervention_reason: Map.get(metadata, :intervention_reason, "unknown"),
      urgency_level: Map.get(metadata, :urgency_level, "medium"),
      component: Map.get(metadata, :component, "system")
    }
  end

  defp get_user_journey_tags(metadata) do
    %{
      journey_type: Map.get(metadata, :journey_type, "general"),
      user_segment: Map.get(metadata, :user_segment, "general"),
      entry_point: Map.get(metadata, :entry_point, "web")
    }
  end

  defp get_response_quality_tags(metadata) do
    %{
      interaction_type: Map.get(metadata, :interaction_type, "general"),
      response_type: Map.get(metadata, :response_type, "generated"),
      ai_model: Map.get(metadata, :ai_model, "claude")
    }
  end

  defp get_user_engagement_tags(metadata) do
    %{
      feature_area: Map.get(metadata, :feature_area, "core"),
      user_segment: Map.get(metadata, :user_segment, "general"),
      session_type: Map.get(metadata, :session_type, "interactive")
    }
  end

  defp get_feedback_sentiment_tags(metadata) do
    %{
      feedback_type: Map.get(metadata, :feedback_type, "general"),
      feedback_source: Map.get(metadata, :feedback_source, "app"),
      topic_category: Map.get(metadata, :topic_category, "feature")
    }
  end

  defp get_revenue_tags(metadata) do
    %{
      revenue_source: Map.get(metadata, :revenue_source, "subscription"),
      customer_segment: Map.get(metadata, :customer_segment, "enterprise"),
      product_area: Map.get(metadata, :product_area, "core")
    }
  end

  defp get_cost_savings_tags(metadata) do
    %{
      optimization_type: Map.get(metadata, :optimization_type, "automation"),
      cost_category: Map.get(metadata, :cost_category, "operational"),
      savings_source: Map.get(metadata, :savings_source, "efficiency")
    }
  end

  defp get_monthly_users_tags(_metadata) do
    %{
      user_type: "active",
      engagement_level: "medium"
    }
  end

  defp get_customer_ltv_tags(_metadata) do
    %{
      customer_segment: "enterprise",
      acquisition_channel: "direct"
    }
  end

  defp get_churn_rate_tags(_metadata) do
    %{
      customer_segment: "enterprise",
      time_period: "monthly",
      churn_reason: "unknown"
    }
  end

  ## Utility Functions

  defp sanitize_feature_name(name) do
    # Sanitize feature names to prevent cardinality explosion
    case name do
      name when is_binary(name) ->
        name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9_]/, "_")
        |> String.slice(0, 30)

      _ ->
        "unknown"
    end
  end
end
