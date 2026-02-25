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

  getItemGroups({ assistantId } = {}) {
    return axios.get(`${this.url}/${assistantId}/erp_proxy/item_groups`);
  }

  getWarehouses({ assistantId } = {}) {
    return axios.get(`${this.url}/${assistantId}/erp_proxy/warehouses`);
  }

  setup({ assistantId, erpCompany, erpWarehouse }) {
    return axios.post(`${this.url}/${assistantId}/erp_proxy/setup`, {
      erp_company: erpCompany,
      erp_warehouse: erpWarehouse,
    });
  }
}

export default new CaptainErpProxy();
