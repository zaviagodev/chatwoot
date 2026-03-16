import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import CardDesignAPI from '../../api/cardDesign';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
  },
};

const getters = {
  getCardDesigns(_state) {
    return _state.records;
  },
  getCardDesignUIFlags(_state) {
    return _state.uiFlags;
  },
};

const actions = {
  getCardDesigns: async function getCardDesigns({ commit }) {
    commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { fetchingList: true });
    try {
      const response = await CardDesignAPI.get();
      commit(types.default.SET_CARD_DESIGNS, response.data);
    } catch (error) {
      // silent
    } finally {
      commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { fetchingList: false });
    }
  },

  createCardDesign: async function createCardDesign({ commit }, designObj) {
    commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { creatingItem: true });
    try {
      const response = await CardDesignAPI.create(designObj);
      commit(types.default.ADD_CARD_DESIGN, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { creatingItem: false });
    }
  },

  updateCardDesign: async function updateCardDesign(
    { commit },
    { id, ...updateObj }
  ) {
    commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { updatingItem: true });
    try {
      const response = await CardDesignAPI.update(id, updateObj);
      commit(types.default.EDIT_CARD_DESIGN, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { updatingItem: false });
    }
  },

  deleteCardDesign: async function deleteCardDesign({ commit }, id) {
    commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { deletingItem: true });
    try {
      await CardDesignAPI.delete(id);
      commit(types.default.DELETE_CARD_DESIGN, id);
      return id;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.default.SET_CARD_DESIGNS_UI_FLAG, { deletingItem: false });
    }
  },

  setDefaultCardDesign: async function setDefaultCardDesign({ dispatch }, id) {
    try {
      await CardDesignAPI.setDefault(id);
      await dispatch('getCardDesigns');
      return undefined;
    } catch (error) {
      return throwErrorMessage(error);
    }
  },

  duplicateCardDesign: async function duplicateCardDesign({ commit }, id) {
    try {
      const response = await CardDesignAPI.duplicate(id);
      commit(types.default.ADD_CARD_DESIGN, response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_CARD_DESIGNS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.default.SET_CARD_DESIGNS]: MutationHelpers.set,
  [types.default.ADD_CARD_DESIGN]: MutationHelpers.create,
  [types.default.EDIT_CARD_DESIGN]: MutationHelpers.update,
  [types.default.DELETE_CARD_DESIGN]: MutationHelpers.destroy,
};

export default {
  state,
  getters,
  actions,
  mutations,
};
