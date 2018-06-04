class FeedbackController < ApplicationController
  before_action :set_register

  def create
    @feedback = Feedback.new(feedback_params)

    if @feedback.valid?
      if @feedback.message.present?
        @zendesk_service = ZendeskFeedback.new
        @response = @zendesk_service.send_feedback(feedback_params)
      end
      flash[:success] = 'Thank you for your feedback'
      redirect_to register_path(@register.slug)
    else
      render 'registers/show'
    end
  end

private

  def set_register
    @register = Register.find_by_slug!(params[:register_id])
  end

  def feedback_params
    params.require(:feedback).permit(
      :subject,
      :email,
      :message,
      :useful,
      :reason
    )
  end
end