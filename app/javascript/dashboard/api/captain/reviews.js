/* global axios */
import ApiClient from '../ApiClient';

function buildFormData(data) {
  const formData = new FormData();
  if (data.reviewer_name) formData.append('reviewer_name', data.reviewer_name);
  if (data.rating != null) formData.append('rating', data.rating);
  if (data.review_text) formData.append('review_text', data.review_text);
  // Always send captain_product_id — empty string clears the link on the backend
  // (Rails converts '' to nil for integer columns via assign_attributes)
  formData.append('captain_product_id', data.captain_product_id || '');
  (data.category_tags || []).forEach(tag =>
    formData.append('category_tags[]', tag)
  );
  (data.photos || []).forEach(photo => formData.append('photos[]', photo));
  (data.removed_photo_signed_ids || []).forEach(signedId =>
    formData.append('removed_photo_signed_ids[]', signedId)
  );
  return formData;
}

class CaptainReviews extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ page = 1, assistantId, search, category } = {}) {
    return axios.get(`${this.url}/${assistantId}/reviews`, {
      params: { page, search, category },
    });
  }

  show({ assistantId, id }) {
    return axios.get(`${this.url}/${assistantId}/reviews/${id}`);
  }

  create({ assistantId, ...data }) {
    const formData = buildFormData(data);
    return axios.post(`${this.url}/${assistantId}/reviews`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  update({ assistantId, id, ...data }) {
    const formData = buildFormData(data);
    return axios.patch(`${this.url}/${assistantId}/reviews/${id}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  delete({ assistantId, id }) {
    return axios.delete(`${this.url}/${assistantId}/reviews/${id}`);
  }

  getDistinctCategories({ assistantId }) {
    return axios.get(`${this.url}/${assistantId}/reviews/distinct_categories`);
  }

  bulkDelete({ assistantId, ids }) {
    return axios.delete(`${this.url}/${assistantId}/reviews/bulk_destroy`, {
      data: { ids },
    });
  }
}

export default new CaptainReviews();
