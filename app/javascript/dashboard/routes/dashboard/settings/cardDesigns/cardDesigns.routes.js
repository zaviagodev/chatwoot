import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import CardDesignsIndex from './Index.vue';
import CardDesignsEditor from './Editor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/card-designs'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'card_designs_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'card_designs_list',
          meta: {
            permissions: [...ROLES],
          },
          component: CardDesignsIndex,
        },
        {
          path: 'new',
          name: 'card_designs_new',
          meta: {
            permissions: [...ROLES],
          },
          component: CardDesignsEditor,
        },
        {
          path: ':designId/edit',
          name: 'card_designs_edit',
          meta: {
            permissions: [...ROLES],
          },
          component: CardDesignsEditor,
        },
      ],
    },
  ],
};
