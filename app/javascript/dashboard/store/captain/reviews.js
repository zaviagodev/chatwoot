import CaptainReviewsAPI from 'dashboard/api/captain/reviews';
import { createStore } from '../storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export default createStore({
  name: 'CaptainReview',
  API: CaptainReviewsAPI,
  actions: mutations => ({
    create: async ({ commit }, { assistantId, ...data }) => {
      commit(mutations.SET_UI_FLAG, { creatingItem: true });
      try {
        const response = await CaptainReviewsAPI.create({
          assistantId,
          ...data,
        });
        commit(mutations.ADD, response.data);
        commit(mutations.SET_UI_FLAG, { creatingItem: false });
        return response.data;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { creatingItem: false });
        return throwErrorMessage(error);
      }
    },

    update: async ({ commit }, { id, assistantId, ...updateObj }) => {
      commit(mutations.SET_UI_FLAG, { updatingItem: true });
      try {
        const response = await CaptainReviewsAPI.update({
          id,
          assistantId,
          ...updateObj,
        });
        commit(mutations.EDIT, response.data);
        commit(mutations.SET_UI_FLAG, { updatingItem: false });
        return response.data;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { updatingItem: false });
        return throwErrorMessage(error);
      }
    },

    delete: async ({ commit }, { id, assistantId }) => {
      commit(mutations.SET_UI_FLAG, { deletingItem: true });
      try {
        await CaptainReviewsAPI.delete({ id, assistantId });
        commit(mutations.DELETE, id);
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return id;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return throwErrorMessage(error);
      }
    },
  }),
});
