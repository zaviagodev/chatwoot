import CaptainProductsAPI from 'dashboard/api/captain/products';
import { createStore } from '../storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const syncStatusDefaults = {
  lastSyncedAt: null,
  syncErrorCount: 0,
  syncInterval: 3600,
  isSyncing: false,
};

export default createStore({
  name: 'CaptainProduct',
  API: CaptainProductsAPI,
  getters: {
    getSyncStatus: state => state.syncStatus || syncStatusDefaults,
  },
  mutations: {
    SET_SYNC_STATUS(state, payload) {
      state.syncStatus = {
        ...(state.syncStatus || syncStatusDefaults),
        ...payload,
      };
    },
    INIT_SYNC_STATUS(state) {
      if (!state.syncStatus) {
        state.syncStatus = { ...syncStatusDefaults };
      }
    },
  },
  actions: mutations => ({
    update: async ({ commit }, { id, assistantId, ...updateObj }) => {
      commit(mutations.SET_UI_FLAG, { updatingItem: true });
      try {
        const response = await CaptainProductsAPI.update({
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
        await CaptainProductsAPI.delete({ id, assistantId });
        commit(mutations.DELETE, id);
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return id;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return throwErrorMessage(error);
      }
    },

    syncProducts: async ({ commit, state }, { assistantId }) => {
      commit('INIT_SYNC_STATUS');
      if (state.syncStatus.isSyncing) return null;
      commit('SET_SYNC_STATUS', { isSyncing: true });
      try {
        const { data } = await CaptainProductsAPI.sync({ assistantId });
        commit('SET_SYNC_STATUS', {
          isSyncing: false,
          lastSyncedAt: data.last_synced_at,
          syncErrorCount: 0,
        });
        return data;
      } catch (error) {
        commit('SET_SYNC_STATUS', { isSyncing: false });
        return throwErrorMessage(error);
      }
    },

    fetchSyncStatus: async ({ commit }, { assistantId }) => {
      commit('INIT_SYNC_STATUS');
      try {
        const { data } = await CaptainProductsAPI.getSyncStatus({
          assistantId,
        });
        commit('SET_SYNC_STATUS', {
          lastSyncedAt: data.last_synced_at,
          syncErrorCount: data.sync_error_count,
          syncInterval: data.sync_interval,
        });
        return data;
      } catch {
        // Silently fail — sync status is non-critical
      }
      return null;
    },

    enrichProduct: async (_ctx, { assistantId, id }) => {
      try {
        const { data } = await CaptainProductsAPI.enrich({
          assistantId,
          id,
        });
        return data;
      } catch (error) {
        return throwErrorMessage(error);
      }
    },

    approveEnrichment: async ({ commit }, { assistantId, id, text }) => {
      try {
        const { data } = await CaptainProductsAPI.approveEnrichment({
          assistantId,
          id,
          text,
        });
        commit(mutations.EDIT, data);
        return data;
      } catch (error) {
        return throwErrorMessage(error);
      }
    },
  }),
});
