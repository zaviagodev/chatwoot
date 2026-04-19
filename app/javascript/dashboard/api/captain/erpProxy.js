/* global axios */
import ApiClient from '../ApiClient';

class CaptainErpProxy extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  searchProducts({ query, itemGroup, page = 1, assistantId } = {}) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/search_products`, {
      query,
      item_group: itemGroup,
      page,
    });
  }

  getProductDetail({ assistantId, itemCode } = {}) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/product_detail`, {
      item_code: itemCode,
    });
  }

  getVariants({ assistantId, itemCode } = {}) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/variants`, {
      item_code: itemCode,
    });
  }

  getItemGroups({ assistantId } = {}) {
    return axios.get(`${this.url}/${assistantId}/erp_proxy/item_groups`);
  }

  getWarehouses({ assistantId } = {}) {
    return axios.get(`${this.url}/${assistantId}/erp_proxy/warehouses`);
  }

  createSharedCheckout({
    assistantId,
    items,
    customerEmail,
    addressName,
    addressData,
    lineUserId,
    registerCustomer,
    conversationId,
  } = {}) {
    return axios.post(
      `${this.url}/${assistantId}/erp_proxy/create_shared_checkout`,
      {
        items,
        customer_email: customerEmail,
        address_name: addressName,
        address_data: addressData,
        line_user_id: lineUserId,
        register_customer: registerCustomer,
        conversation_id: conversationId,
      }
    );
  }

  searchThaiAddress({ assistantId, query } = {}) {
    return axios.post(
      `${this.url}/${assistantId}/erp_proxy/search_thai_address`,
      { query }
    );
  }

  lookupLineCustomer({ assistantId, lineUserId, signal } = {}) {
    return axios.post(
      `${this.url}/${assistantId}/erp_proxy/lookup_line_customer`,
      { line_user_id: lineUserId },
      signal ? { signal } : {}
    );
  }

  getCustomization({ assistantId, itemCode } = {}) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/customization`, {
      item_code: itemCode,
    });
  }

  getBundleInfo({ assistantId, itemCode } = {}) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/bundle_info`, {
      item_code: itemCode,
    });
  }

  uploadCustomizationFile({ assistantId, file } = {}) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(
      `${this.url}/${assistantId}/erp_proxy/upload_file`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  }

  setup({ assistantId, erpCompany, erpWarehouse }) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/setup`, {
      erp_company: erpCompany,
      erp_warehouse: erpWarehouse,
    });
  }
}

export default new CaptainErpProxy();
