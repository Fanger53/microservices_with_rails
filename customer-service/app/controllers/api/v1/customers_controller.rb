module Api
  module V1
    class CustomersController < ApplicationController
      before_action :set_customer, only: [:show, :update, :destroy]

      def index
        customers = Customer.where(filter_conditions)
                           .order(sort_order)
                           .limit(params[:per_page] || 20)
                           .offset(params[:page].to_i * (params[:per_page] || 20).to_i)

        render json: customers
      end

      def show
        render json: @customer
      end

      def create
        customer = Customer.new(customer_params)
        
        if customer.save
          render json: customer, status: :created
        else
          render_error(customer.errors.full_messages, :unprocessable_entity)
        end
      end

      def update
        if @customer.update(customer_params)
          render json: @customer
        else
          render_error(@customer.errors.full_messages, :unprocessable_entity)
        end
      end

      def destroy
        @customer.update!(status: :deleted)
        render json: { message: 'Cliente eliminado correctamente' }
      end

      # Endpoint para validar si puede facturar
      def validate_invoice_capability
        customer = Customer.find(params[:id])
        
        render json: {
          can_invoice: customer.can_invoice?,
          tax_info: customer.tax_info,
          validation_errors: customer.can_invoice? ? [] : invoice_validation_errors(customer)
        }
      end

      private

      def set_customer
        @customer = Customer.find(params[:id])
      end

      def customer_params
        params.require(:customer).permit(
          :tax_id, :name, :email, :phone, 
          :address, :city, :country,
          :tax_regime, :company_size, :status
        )
      end

      def filter_conditions
        conditions = {}
        conditions[:status] = params[:status] if params[:status].present?
        conditions[:tax_regime] = params[:tax_regime] if params[:tax_regime].present?
        conditions[:company_size] = params[:company_size] if params[:company_size].present?
        
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          conditions = conditions.merge(
            Customer.where("name ILIKE ? OR tax_id ILIKE ? OR email ILIKE ?", 
                          search_term, search_term, search_term)
          )
        end
        
        conditions
      end

      def sort_order
        case params[:sort_by]
        when 'name'
          { name: params[:order] || 'asc' }
        when 'created_at'
          { created_at: params[:order] || 'desc' }
        else
          { created_at: :desc }
        end
      end

      def invoice_validation_errors(customer)
        errors = []
        errors << "Cliente inactivo" unless customer.active?
        errors << "Tax ID faltante" unless customer.tax_id.present?
        errors << "Email faltante" unless customer.email.present?
        errors << "Información fiscal incompleta" unless customer.valid_tax_info?
        errors
      end
    end
  end
end