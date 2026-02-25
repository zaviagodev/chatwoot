/* global axios */
import ApiClient from '../ApiClient';

class CaptainProducts extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ page = 1, assistantId, itemGroup } = {}) {
    return axios.get(`${this.url}/${assistantId}/products`, {
      params: { page, item_group: itemGroup },
    });
  }

  show({ assistantId, id }) {
    return axios.get(`${this.url}/${assistantId}/products/${id}`);
  }

  create({ assistantId, ...data }) {
    return axios.post(`${this.url}/${assistantId}/products`, data);
  }

  update({ assistantId, id, ...data }) {
    return axios.patch(`${this.url}/${assistantId}/products/${id}`, data);
  }

  delete({ assistantId, id }) {
    return axios.delete(`${this.url}/${assistantId}/products/${id}`);
  }

  sync({ assistantId }) {
    return axios.post(`${this.url}/${assistantId}/products/sync`);
  }

  getSyncStatus({ assistantId }) {
    return axios.get(`${this.url}/${assistantId}/products/sync_status`);
  }

  enrich({ assistantId, id }) {
    return axios.post(`${this.url}/${assistantId}/products/${id}/enrich`);
  }

  approveEnrichment({ assistantId, id, text }) {
    return axios.put(
      `${this.url}/${assistantId}/products/${id}/approve_enrichment`,
      { text }
    );
  }
}

export default new CaptainProducts();
