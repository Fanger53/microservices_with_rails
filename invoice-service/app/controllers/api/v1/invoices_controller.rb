module Api
  module V1
    class InvoicesController < ApplicationController
      before_action :set_invoice, only: [:show, :update, :destroy, :calculate_taxes, :generate_pdf, :send_to_dian, :cancel, :status]

      def index
        invoices = Invoice.includes(:invoice_items)
                         .where(filter_conditions)
                         .order(sort_order)

        paginated = paginate_collection(
          invoices, 
          page: params[:page], 
          per_page: params[:per_page]
        )

        render_success(
          paginated[:collection], 
          InvoiceSerializer, 
          :ok, 
          paginated[:meta]
        )
      end

      def show
        render_success(@invoice, InvoiceSerializer)
      end

      def create
        # Validar que el cliente existe
        customer = fetch_customer(invoice_params[:customer_id])
        return render_error("Cliente no encontrado", :not_found) unless customer

        # Validar que el cliente puede ser facturado
        unless customer_can_invoice?(customer)
          return render_error("Cliente no habilitado para facturación", :unprocessable_entity)
        end

        invoice = Invoice.new(invoice_params)
        
        if invoice.save
          # Crear items si se proporcionaron
          create_invoice_items(invoice, params[:items]) if params[:items].present?
          
          invoice.reload
          render_success(invoice, InvoiceSerializer, :created)
        else
          render_error(invoice.errors.full_messages, :unprocessable_entity)
        end
      end

      def update
        return render_error("No se puede editar factura emitida", :forbidden) unless @invoice.can_be_edited?

        if @invoice.update(invoice_params)
          # Actualizar items si se proporcionaron
          update_invoice_items(@invoice, params[:items]) if params[:items].present?
          
          @invoice.reload
          render_success(@invoice, InvoiceSerializer)
        else
          render_error(@invoice.errors.full_messages, :unprocessable_entity)
        end
      end

      def destroy
        return render_error("No se puede eliminar factura emitida", :forbidden) unless @invoice.draft?

        @invoice.destroy!
        render json: { message: 'Factura eliminada correctamente' }
      end

      def calculate_taxes
        @invoice.calculate_totals!
        render_success(@invoice, InvoiceSerializer)
      end

      def generate_pdf
        return render_error("Factura debe estar emitida", :unprocessable_entity) unless @invoice.issued?

        @invoice.generate_pdf!
        render json: { 
          message: 'Generación de PDF iniciada',
          invoice_id: @invoice.id 
        }
      end

      def send_to_dian
        return render_error("Factura no lista para DIAN", :unprocessable_entity) unless @invoice.can_send_to_dian?

        @invoice.send_to_dian!
        render json: { 
          message: 'Envío a DIAN iniciado',
          invoice_id: @invoice.id 
        }
      end

      def cancel
        return render_error("No se puede cancelar esta factura", :forbidden) unless @invoice.can_be_cancelled?

        if @invoice.cancel!(
          reason: params[:reason],
          cancelled_by: params[:cancelled_by]
        )
          render_success(@invoice, InvoiceSerializer)
        else
          render_error(@invoice.errors.full_messages, :unprocessable_entity)
        end
      end

      def status
        render json: {
          invoice_id: @invoice.id,
          status: @invoice.status,
          payment_status: @invoice.payment_status,
          dian_status: @invoice.dian_uuid.present? ? 'sent' : 'pending',
          can_be_cancelled: @invoice.can_be_cancelled?,
          can_be_edited: @invoice.can_be_edited?,
          is_overdue: @invoice.is_overdue?,
          days_overdue: @invoice.days_overdue
        }
      end

      def search
        query = params[:q]
        return render_error("Parámetro de búsqueda requerido", :bad_request) if query.blank?

        invoices = Invoice.joins("LEFT JOIN invoice_items ON invoices.id = invoice_items.invoice_id")
                         .where(
                           "invoices.invoice_number ILIKE ? OR invoice_items.description ILIKE ?",
                           "%#{query}%", "%#{query}%"
                         )
                         .distinct
                         .includes(:invoice_items)

        paginated = paginate_collection(
          invoices, 
          page: params[:page], 
          per_page: params[:per_page]
        )

        render_success(
          paginated[:collection], 
          InvoiceSerializer, 
          :ok, 
          paginated[:meta]
        )
      end

      def summary
        date_from = params[:date_from]&.to_date || Date.current.beginning_of_month
        date_to = params[:date_to]&.to_date || Date.current.end_of_month

        invoices = Invoice.by_date_range(date_from, date_to)

        summary = {
          total_invoices: invoices.count,
          total_amount: invoices.sum(:total_amount),
          total_tax: invoices.sum(:tax_amount),
          by_status: invoices.group(:status).count,
          by_payment_status: invoices.group(:payment_status).count,
          pending_dian: invoices.where(dian_uuid: nil).count,
          overdue_count: invoices.select(&:is_overdue?).count
        }

        render json: { summary: summary, period: { from: date_from, to: date_to } }
      end

      private

      def set_invoice
        @invoice = Invoice.find(params[:id])
      end

      def invoice_params
        params.require(:invoice).permit(
          :customer_id, :invoice_type, :issue_date, :due_date,
          :currency, :discount_amount, :notes, :internal_notes
        )
      end

      def filter_conditions
        conditions = {}
        conditions[:status] = params[:status] if params[:status].present?
        conditions[:payment_status] = params[:payment_status] if params[:payment_status].present?
        conditions[:customer_id] = params[:customer_id] if params[:customer_id].present?
        
        if params[:date_from].present? && params[:date_to].present?
          conditions[:issue_date] = params[:date_from]..params[:date_to]
        end
        
        conditions
      end

      def sort_order
        case params[:sort_by]
        when 'invoice_number'
          { invoice_number: params[:order] || 'asc' }
        when 'total_amount'
          { total_amount: params[:order] || 'desc' }
        when 'issue_date'
          { issue_date: params[:order] || 'desc' }
        else
          { created_at: :desc }
        end
      end

      def fetch_customer(customer_id)
        # Llamada al Customer Service
        CustomerServiceClient.find_customer(customer_id)
      rescue => e
        Rails.logger.error "Error fetching customer #{customer_id}: #{e.message}"
        nil
      end

      def customer_can_invoice?(customer)
        customer.present? && customer['status'] == 'active' && customer['can_invoice'] == true
      end

      def create_invoice_items(invoice, items_params)
        items_params.each_with_index do |item_params, index|
          invoice.invoice_items.create!(
            item_params.permit(:product_code, :description, :quantity, :unit_price, :tax_rate)
                      .merge(line_number: index + 1)
          )
        end
      end

      def update_invoice_items(invoice, items_params)
        # Eliminar items existentes y crear nuevos (estrategia simple)
        invoice.invoice_items.destroy_all
        create_invoice_items(invoice, items_params)
      end
    end
  end
end