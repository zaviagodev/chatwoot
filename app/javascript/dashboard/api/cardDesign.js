/* global axios */

import ApiClient from './ApiClient';

class CardDesignAPI extends ApiClient {
  constructor() {
    super('card_designs', { accountScoped: true });
  }

  setDefault(id) {
    return axios.post(`${this.url}/${id}/set_default`);
  }

  duplicate(id) {
    return axios.post(`${this.url}/${id}/duplicate`);
  }
}

export default new CardDesignAPI();
