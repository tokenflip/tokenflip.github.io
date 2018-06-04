import Troubleshoot from '@/components/Troubleshoot'
import FlipCoin from '@/components/FlipCoin'

const routes = [
  {
    path: '/',
    name: 'FlipCoin',
    component: FlipCoin
  },
  {
    path: '/troubleshoot',
    name: 'Troubleshoot',
    component: Troubleshoot
  },
  {
    path: '*',
    redirect: '/'
  }
]

export default routes
