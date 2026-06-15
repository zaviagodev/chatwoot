/* global axios */
import ApiClient from '../ApiClient';

class CaptainResponseHistory extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ page = 1, assistantId, search } = {}) {
    return axios.get(`${this.url}/${assistantId}/response_history`, {
      params: { page, search },
    });
  }
}

export default new CaptainResponseHistory();
