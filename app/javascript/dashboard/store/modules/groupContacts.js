import ConversationsAPI from '../../api/conversations';

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
  },
};

const getters = {
  getGroupContacts: $state => conversationId => {
    return $state.records[conversationId] || [];
  },
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  async fetch({ commit }, conversationId) {
    commit('setUIFlag', { isFetching: true });
    try {
      const { data } = await ConversationsAPI.getGroupContacts(conversationId);
      commit('setGroupContacts', {
        conversationId,
        contacts: data.payload || [],
      });
    } catch (error) {
      // silently fail
    } finally {
      commit('setUIFlag', { isFetching: false });
    }
  },
};

const mutations = {
  setUIFlag($state, flag) {
    $state.uiFlags = { ...$state.uiFlags, ...flag };
  },
  setGroupContacts($state, { conversationId, contacts }) {
    $state.records = {
      ...$state.records,
      [conversationId]: contacts,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
