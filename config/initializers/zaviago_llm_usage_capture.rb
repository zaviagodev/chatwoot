# Zaviago LLM Usage Capture
#
# The ai-agents gem (v0.7.0) creates RubyLLM::Chat instances internally but
# doesn't populate RunResult.usage with actual token counts. This initializer
# prepends a module on RubyLLM::Chat#initialize to automatically capture
# input_tokens, output_tokens, and model from every LLM response into
# Thread.current[:captain_llm_usage].
#
# Consumed by Captain::Assistant::AgentRunnerService#process_agent_result
# to thread token data through to the copilot draft and message content_attributes.

module ZaviagoLlmUsageCapture
  def initialize(*, **)
    super
    on_end_message do |message|
      Thread.current[:captain_llm_usage] = {
        input_tokens: message.respond_to?(:input_tokens) ? message.input_tokens : nil,
        output_tokens: message.respond_to?(:output_tokens) ? message.output_tokens : nil,
        model: model.to_s
      }
    rescue StandardError => e
      Rails.logger.warn "[Zaviago] LLM usage capture error: #{e.message}"
    end
  end
end

Rails.application.config.after_initialize do
  if defined?(RubyLLM::Chat)
    RubyLLM::Chat.prepend(ZaviagoLlmUsageCapture)
    Rails.logger.info '[Zaviago] LLM usage capture hook installed on RubyLLM::Chat'
  end
end
